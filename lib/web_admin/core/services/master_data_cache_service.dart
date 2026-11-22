import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single cache entry with a shared clock for TTL and stale checks.
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;
  final DateTime Function() _clock;

  CacheEntry({
    required this.data,
    required this.ttl,
    DateTime? timestamp,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       timestamp = timestamp ?? (clock ?? DateTime.now)();

  bool get isExpired => _clock().difference(timestamp) > ttl;
  bool get isStale => _clock().difference(timestamp) > (ttl * 0.7);
}

/// In-memory master data cache with stale-while-revalidate behavior.
class MasterDataCacheService {
  MasterDataCacheService({SupabaseClient? client, DateTime Function()? clock})
    : _client = client,
      _clock = clock ?? DateTime.now;

  static final MasterDataCacheService instance = MasterDataCacheService();
  static const Duration defaultMasterDataTtl = Duration(minutes: 5);
  static const Duration defaultSiswaTtl = Duration(minutes: 3);

  final SupabaseClient? _client;
  final DateTime Function() _clock;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  late final _kelasCache = _CachedRows(
    clock: _clock,
    fetch: () async => List<Map<String, dynamic>>.from(
      await _supabase
          .from('kelas')
          .select('id, nama_kelas')
          .order('nama_kelas'),
    ),
  );
  late final _guruCache = _CachedRows(
    clock: _clock,
    fetch: () async => List<Map<String, dynamic>>.from(
      await _supabase
          .from('guru')
          .select('id, nama, email, role, avatar_url, kelas_diampu')
          .order('nama'),
    ),
  );
  final _siswaByKelasCache = <int, _CachedRows>{};

  Future<List<Map<String, dynamic>>> getKelasList({
    bool forceRefresh = false,
    Duration ttl = defaultMasterDataTtl,
  }) => _kelasCache.get(forceRefresh: forceRefresh, ttl: ttl);

  Future<List<Map<String, dynamic>>> getGuruList({
    bool forceRefresh = false,
    Duration ttl = defaultMasterDataTtl,
  }) => _guruCache.get(forceRefresh: forceRefresh, ttl: ttl);

  Future<List<Map<String, dynamic>>> getActiveSiswaByKelas(
    int kelasId, {
    bool forceRefresh = false,
    Duration ttl = defaultSiswaTtl,
  }) => _siswaByKelasCache
      .putIfAbsent(
        kelasId,
        () => _CachedRows(
          clock: _clock,
          fetch: () async => List<Map<String, dynamic>>.from(
            await _supabase
                .from('siswa')
                .select(
                  'id, nis, nama, orang_tua_nama, orang_tua_nomor, status',
                )
                .eq('kelas_id', kelasId)
                .eq('status', 'aktif')
                .order('nama'),
          ),
        ),
      )
      .get(forceRefresh: forceRefresh, ttl: ttl);

  void invalidateKelas() => _kelasCache.invalidate();
  void invalidateGuru() => _guruCache.invalidate();

  /// Student mutations invalidate every class unless a specific scope is known.
  void invalidateSiswa({int? kelasId}) {
    if (kelasId != null) {
      _siswaByKelasCache[kelasId]?.invalidate();
    } else {
      for (final cache in _siswaByKelasCache.values) {
        cache.invalidate();
      }
    }
  }

  void invalidateAll() {
    invalidateKelas();
    invalidateGuru();
    invalidateSiswa();
  }
}

/// One lifecycle for each class, teacher list, or student list.
class _CachedRows {
  _CachedRows({required this.fetch, required this.clock});

  final Future<List<Map<String, dynamic>>> Function() fetch;
  final DateTime Function() clock;
  CacheEntry<List<Map<String, dynamic>>>? _entry;
  Future<List<Map<String, dynamic>>>? _pending;
  int _generation = 0;

  Future<List<Map<String, dynamic>>> get({
    bool forceRefresh = false,
    required Duration ttl,
  }) async {
    final entry = _entry;
    if (!forceRefresh && entry != null && !entry.isExpired) {
      if (entry.isStale) {
        unawaited(
          _refresh(ttl).then<void>(
            (_) {},
            onError: (Object error) {
              debugPrint('[MasterDataCache] Background refresh failed: $error');
            },
          ),
        );
      }
      return _copyRows(entry.data);
    }
    return _copyRows(await _refresh(ttl));
  }

  Future<List<Map<String, dynamic>>> _refresh(Duration ttl) =>
      _pending ??= _fetchAndCache(ttl, _generation);

  Future<List<Map<String, dynamic>>> _fetchAndCache(
    Duration ttl,
    int generation,
  ) async {
    try {
      List<Map<String, dynamic>> data;
      try {
        data = await Future.sync(fetch);
      } catch (error) {
        // An invalidated request must not restore stale data through fallback.
        if (generation != _generation) return get(ttl: ttl);
        debugPrint('[MasterDataCache] Fetch failed: $error');
        final fallback = _entry;
        if (fallback != null) return fallback.data;
        rethrow;
      }

      if (generation != _generation) return get(ttl: ttl);
      _entry = CacheEntry(data: _copyRows(data), ttl: ttl, clock: clock);
      return _entry!.data;
    } finally {
      // An old completion must not detach a newer request.
      if (generation == _generation) _pending = null;
    }
  }

  void invalidate() {
    _generation++;
    _entry = null;
    _pending = null;
  }

  List<Map<String, dynamic>> _copyRows(List<Map<String, dynamic>> rows) =>
      rows.map((row) => Map<String, dynamic>.from(row)).toList();
}
