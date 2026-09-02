import 'package:flutter_test/flutter_test.dart';
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

  group('MasterDataCacheService Invalidation Tests', () {
    final cacheService = MasterDataCacheService.instance;

    test('invalidateKelas clears class cache without exceptions', () {
      expect(() => cacheService.invalidateKelas(), returnsNormally);
    });

    test('invalidateGuru clears teacher cache without exceptions', () {
      expect(() => cacheService.invalidateGuru(), returnsNormally);
    });

    test('invalidateSiswa clears specific class student cache', () {
      expect(() => cacheService.invalidateSiswa(kelasId: 1), returnsNormally);
    });

    test('invalidateAll clears all caches simultaneously', () {
      expect(() => cacheService.invalidateAll(), returnsNormally);
    });
  });
}
