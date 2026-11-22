import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_admin_mts/web_admin/core/services/master_data_cache_service.dart';

void main() {
  group('CacheEntry Tests', () {
    test('CacheEntry correctly determines freshness and expiration', () {
      final entry = CacheEntry<String>(
        data: 'test_data',
        ttl: const Duration(seconds: 10),
      );

      expect(entry.data, 'test_data');
      expect(entry.isExpired, isFalse);
    });

    test('CacheEntry marks expired when timestamp is in past', () {
      final entry = CacheEntry<String>(
        data: 'expired_data',
        ttl: const Duration(seconds: 5),
        timestamp: DateTime.now().subtract(const Duration(seconds: 10)),
      );

      expect(entry.isExpired, isTrue);
    });

    test('CacheEntry marks stale when approaching 70% of TTL', () {
      final entry = CacheEntry<String>(
        data: 'stale_data',
        ttl: const Duration(seconds: 10),
        timestamp: DateTime.now().subtract(const Duration(seconds: 8)),
      );

      expect(entry.isStale, isTrue);
    });
  });

  final cases = <_CacheCase>[
    _CacheCase(
      'kelas',
      (cache, force) => cache.getKelasList(
        forceRefresh: force,
        ttl: const Duration(seconds: 10),
      ),
      (cache) => cache.invalidateKelas(),
    ),
    _CacheCase(
      'guru',
      (cache, force) => cache.getGuruList(
        forceRefresh: force,
        ttl: const Duration(seconds: 10),
      ),
      (cache) => cache.invalidateGuru(),
    ),
    _CacheCase(
      'siswa',
      (cache, force) => cache.getActiveSiswaByKelas(
        1,
        forceRefresh: force,
        ttl: const Duration(seconds: 10),
      ),
      (cache) => cache.invalidateSiswa(kelasId: 1),
    ),
  ];

  for (final scenario in cases) {
    group('${scenario.name} cache lifecycle', () {
      late MasterDataCacheService cache;
      late DateTime now;
      late Future<http.Response> Function(http.Request) respond;
      late int requests;

      setUp(() {
        now = DateTime(2026, 11, 22);
        requests = 0;
        respond = (_) async => _rows(1);
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          httpClient: MockClient((request) async {
            requests++;
            final response = await respond(request);
            return http.Response.bytes(
              response.bodyBytes,
              response.statusCode,
              headers: response.headers,
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        cache = MasterDataCacheService(client: client, clock: () => now);
      });

      test(
        'fresh reads use cache and force refresh fetches new data',
        () async {
          await scenario.read(cache, false);
          respond = (_) async => _rows(2);
          expect((await scenario.read(cache, false)).single['id'], 1);
          expect(requests, 1);
          expect((await scenario.read(cache, true)).single['id'], 2);
          expect(requests, 2);
        },
      );

      test('concurrent cache misses share one request', () async {
        final pending = Completer<http.Response>();
        respond = (_) => pending.future;
        final first = scenario.read(cache, false);
        final second = scenario.read(cache, false);
        await pumpEventQueue();
        pending.complete(_rows(1));
        await Future.wait([first, second]);
        expect(requests, 1);
      });

      test(
        'stale reads return immediately and share background refresh',
        () async {
          await scenario.read(cache, false);
          now = now.add(const Duration(seconds: 8));
          final pending = Completer<http.Response>();
          respond = (_) => pending.future;
          for (var i = 0; i < 3; i++) {
            expect((await scenario.read(cache, false)).single['id'], 1);
          }
          pending.complete(_rows(2));
          await pumpEventQueue();
          expect((await scenario.read(cache, false)).single['id'], 2);
          expect(requests, 2);
        },
      );

      test('expired data is refreshed', () async {
        await scenario.read(cache, false);
        now = now.add(const Duration(seconds: 11));
        respond = (_) async => _rows(2);
        expect((await scenario.read(cache, false)).single['id'], 2);
        expect(requests, 2);
      });

      test(
        'failed refresh preserves data until explicit invalidation',
        () async {
          await scenario.read(cache, false);
          now = now.add(const Duration(seconds: 11));
          respond = (_) async => throw StateError('offline');
          expect((await scenario.read(cache, false)).single['id'], 1);
          scenario.invalidate(cache);
          await expectLater(
            scenario.read(cache, false),
            throwsA(isA<StateError>()),
          );
        },
      );

      for (final invalidateAll in [false, true]) {
        test(
          'late response cannot restore data after ${invalidateAll ? 'global' : 'targeted'} invalidation',
          () async {
            final pending = Completer<http.Response>();
            respond = (_) => pending.future;
            final oldRead = scenario.read(cache, false);
            await pumpEventQueue();

            if (invalidateAll) {
              cache.invalidateAll();
            } else {
              scenario.invalidate(cache);
            }
            respond = (_) async => _rows(2);
            final newRows = await scenario.read(cache, false);
            pending.complete(_rows(1));
            final oldRows = await oldRead;

            expect(newRows.single['id'], 2);
            expect(oldRows.single['id'], 2);
            expect((await scenario.read(cache, false)).single['id'], 2);
            expect(requests, 2);
          },
        );
      }

      test('an old completion does not detach the new request', () async {
        final oldResponse = Completer<http.Response>();
        respond = (_) => oldResponse.future;
        final oldRead = scenario.read(cache, false);
        await pumpEventQueue();
        scenario.invalidate(cache);

        final newResponse = Completer<http.Response>();
        respond = (_) => newResponse.future;
        final newRead = scenario.read(cache, false);
        await pumpEventQueue();
        oldResponse.complete(_rows(1));
        await pumpEventQueue();
        final thirdRead = scenario.read(cache, false);
        await pumpEventQueue();
        newResponse.complete(_rows(2));

        final results = await Future.wait([oldRead, newRead, thirdRead]);
        expect(results.map((rows) => rows.single['id']), [2, 2, 2]);
        expect(requests, 2);
      });

      test(
        'an invalidated failed request cannot fall back to previous data',
        () async {
          await scenario.read(cache, false);
          final pending = Completer<http.Response>();
          respond = (_) => pending.future;
          final oldRead = scenario.read(cache, true);
          await pumpEventQueue();
          scenario.invalidate(cache);
          respond = (_) async => throw StateError('offline after invalidation');
          final expectation = expectLater(oldRead, throwsA(isA<StateError>()));
          pending.completeError(StateError('old request failed'));
          await expectation;
          expect(requests, 3);
        },
      );

      test('callers cannot change cached rows through returned maps', () async {
        final rows = await scenario.read(cache, false);
        rows.single['id'] = 999;
        rows.clear();
        expect((await scenario.read(cache, false)).single['id'], 1);
        expect(requests, 1);
      });
    });
  }

  test(
    'student invalidation respects class boundaries and clears all classes',
    () async {
      var requests = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        httpClient: MockClient(
          (request) async => _rows(++requests, request: request),
        ),
      );
      addTearDown(client.dispose);
      final cache = MasterDataCacheService(client: client);
      await cache.getActiveSiswaByKelas(1);
      await cache.getActiveSiswaByKelas(2);
      cache.invalidateSiswa(kelasId: 1);
      expect((await cache.getActiveSiswaByKelas(2)).single['id'], 2);
      expect((await cache.getActiveSiswaByKelas(1)).single['id'], 3);
      cache.invalidateSiswa();
      expect((await cache.getActiveSiswaByKelas(1)).single['id'], 4);
      expect((await cache.getActiveSiswaByKelas(2)).single['id'], 5);
    },
  );
}

http.Response _rows(int id, {http.Request? request}) => http.Response(
  jsonEncode([
    {'id': id, 'nama': 'Fixture $id'},
  ]),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

class _CacheCase {
  final String name;
  final Future<List<Map<String, dynamic>>> Function(
    MasterDataCacheService,
    bool,
  )
  read;
  final void Function(MasterDataCacheService) invalidate;

  _CacheCase(this.name, this.read, this.invalidate);
}
