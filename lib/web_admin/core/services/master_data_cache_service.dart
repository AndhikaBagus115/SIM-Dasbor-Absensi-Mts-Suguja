import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single cache entry wrapper with Time-To-Live (TTL) tracking
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.ttl,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;

  bool get isStale =>
      DateTime.now().difference(timestamp) > (ttl * 0.7); // Stale threshold at 70% of TTL
}

/// Centralized in-memory caching service for frequently accessed master data
/// (Kelas, Guru, and Siswa per kelas) with Stale-While-Revalidate support.
class MasterDataCacheService {
  MasterDataCacheService._();
  static final MasterDataCacheService instance = MasterDataCacheService._();

  // Default TTL: 5 minutes for master data
  static const Duration defaultMasterDataTtl = Duration(minutes: 5);
  // Default TTL: 3 minutes for student lists
  static const Duration defaultSiswaTtl = Duration(minutes: 3);

  CacheEntry<List<Map<String, dynamic>>>? _kelasCache;
  CacheEntry<List<Map<String, dynamic>>>? _guruCache;
  final Map<int, CacheEntry<List<Map<String, dynamic>>>> _siswaByKelasCache = {};

  SupabaseClient get _supabase => Supabase.instance.client;

  // ============================================================
  // KELAS CACHE
  // ============================================================

  /// Get list of all classes, serving from memory cache when valid.
  Future<List<Map<String, dynamic>>> getKelasList({
    bool forceRefresh = false,
    Duration ttl = defaultMasterDataTtl,
  }) async {
    final cached = _kelasCache;

    if (!forceRefresh && cached != null && !cached.isExpired) {
      // Trigger background revalidate if stale
      if (cached.isStale) {
        _revalidateKelasInBackground(ttl);
      }
      return List<Map<String, dynamic>>.from(cached.data);
    }

    return _fetchAndCacheKelas(ttl);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCacheKelas(Duration ttl) async {
    try {
      final response = await _supabase
          .from('kelas')
          .select('id, nama_kelas')
          .order('nama_kelas', ascending: true);

      final data = List<Map<String, dynamic>>.from(response);
      _kelasCache = CacheEntry(data: data, ttl: ttl);
      return data;
    } catch (e) {
      debugPrint('[MasterDataCache] Error fetching kelas: $e');
      if (_kelasCache != null) {
        return List<Map<String, dynamic>>.from(_kelasCache!.data);
      }
      rethrow;
    }
  }

  void _revalidateKelasInBackground(Duration ttl) {
    _fetchAndCacheKelas(ttl).catchError((e) {
      debugPrint('[MasterDataCache] Background revalidate kelas failed: $e');
      return <Map<String, dynamic>>[];
    });
  }

  /// Invalidate cached class list (e.g. after insert/update/delete)
  void invalidateKelas() {
    _kelasCache = null;
    debugPrint('[MasterDataCache] Invalidation: Kelas cache cleared');
  }

  // ============================================================
  // GURU CACHE
  // ============================================================

  /// Get list of all teachers, serving from memory cache when valid.
  Future<List<Map<String, dynamic>>> getGuruList({
    bool forceRefresh = false,
    Duration ttl = defaultMasterDataTtl,
  }) async {
    final cached = _guruCache;

    if (!forceRefresh && cached != null && !cached.isExpired) {
      if (cached.isStale) {
        _revalidateGuruInBackground(ttl);
      }
      return List<Map<String, dynamic>>.from(cached.data);
    }

    return _fetchAndCacheGuru(ttl);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCacheGuru(Duration ttl) async {
    try {
      final response = await _supabase
          .from('guru')
          .select('id, nama, email, role, avatar_url, kelas_diampu')
          .order('nama', ascending: true);

      final data = List<Map<String, dynamic>>.from(response);
      _guruCache = CacheEntry(data: data, ttl: ttl);
      return data;
    } catch (e) {
      debugPrint('[MasterDataCache] Error fetching guru: $e');
      if (_guruCache != null) {
        return List<Map<String, dynamic>>.from(_guruCache!.data);
      }
      rethrow;
    }
  }

  void _revalidateGuruInBackground(Duration ttl) {
    _fetchAndCacheGuru(ttl).catchError((e) {
      debugPrint('[MasterDataCache] Background revalidate guru failed: $e');
      return <Map<String, dynamic>>[];
    });
  }

  /// Invalidate cached teacher list (e.g. after insert/update/delete)
  void invalidateGuru() {
    _guruCache = null;
    debugPrint('[MasterDataCache] Invalidation: Guru cache cleared');
  }

  // ============================================================
  // SISWA PER KELAS CACHE
  // ============================================================

  /// Get active students in a specific class with in-memory caching.
  Future<List<Map<String, dynamic>>> getActiveSiswaByKelas(
    int kelasId, {
    bool forceRefresh = false,
    Duration ttl = defaultSiswaTtl,
  }) async {
    final cached = _siswaByKelasCache[kelasId];

    if (!forceRefresh && cached != null && !cached.isExpired) {
      if (cached.isStale) {
        _revalidateSiswaInBackground(kelasId, ttl);
      }
      return List<Map<String, dynamic>>.from(cached.data);
    }

    return _fetchAndCacheSiswaByKelas(kelasId, ttl);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCacheSiswaByKelas(
    int kelasId,
    Duration ttl,
  ) async {
    try {
      final response = await _supabase
          .from('siswa')
          .select('id, nis, nama, orang_tua_nama, orang_tua_nomor, status')
          .eq('kelas_id', kelasId)
          .eq('status', 'aktif')
          .order('nama', ascending: true);

      final data = List<Map<String, dynamic>>.from(response);
      _siswaByKelasCache[kelasId] = CacheEntry(data: data, ttl: ttl);
      return data;
    } catch (e) {
      debugPrint('[MasterDataCache] Error fetching siswa for kelas $kelasId: $e');
      if (_siswaByKelasCache.containsKey(kelasId)) {
        return List<Map<String, dynamic>>.from(_siswaByKelasCache[kelasId]!.data);
      }
      rethrow;
    }
  }

  void _revalidateSiswaInBackground(int kelasId, Duration ttl) {
    _fetchAndCacheSiswaByKelas(kelasId, ttl).catchError((e) {
      debugPrint('[MasterDataCache] Background revalidate siswa ($kelasId) failed: $e');
      return <Map<String, dynamic>>[];
    });
  }

  /// Invalidate cached student lists (optionally for a specific class ID)
  void invalidateSiswa({int? kelasId}) {
    if (kelasId != null) {
      _siswaByKelasCache.remove(kelasId);
      debugPrint('[MasterDataCache] Invalidation: Siswa cache for kelas $kelasId cleared');
    } else {
      _siswaByKelasCache.clear();
      debugPrint('[MasterDataCache] Invalidation: All Siswa per-kelas caches cleared');
    }
  }

  // ============================================================
  // GLOBAL INVALIDATION
  // ============================================================

  /// Invalidate all in-memory master data caches
  void invalidateAll() {
    invalidateKelas();
    invalidateGuru();
    invalidateSiswa();
    debugPrint('[MasterDataCache] Global Invalidation: All caches purged');
  }
}
