import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_admin_mts/web_admin/core/services/master_data_cache_service.dart';
import 'package:web_admin_mts/web_admin/data/repositories/siswa_repository.dart';
import 'package:web_admin_mts/web_admin/logic/siswa_logic.dart';

void main() {
  late _StudentStore store;
  late MasterDataCacheService cache;
  late SiswaRepository repository;
  late DataSiswaLogic logic;

  setUp(() async {
    store = _StudentStore();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: MockClient((request) async {
        final response = await store.handle(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    cache = MasterDataCacheService(client: client);
    repository = SiswaRepositoryImpl(client, cache: cache);
    logic = DataSiswaLogic(client: client, siswaRepo: repository);
    addTearDown(logic.dispose);
    await cache.getActiveSiswaByKelas(1);
    await cache.getActiveSiswaByKelas(2);
  });

  Future<void> expectClasses(List<int> source, List<int> destination) async {
    expect((await cache.getActiveSiswaByKelas(1)).map((s) => s['id']), source);
    expect(
      (await cache.getActiveSiswaByKelas(2)).map((s) => s['id']),
      destination,
    );
  }

  test(
    'repository move invalidates both source and destination classes',
    () async {
      await repository.updateSiswa(1, {'kelas_id': 2});
      await expectClasses([], [1, 2]);
    },
  );

  test(
    'editing from the controller uses the repository mutation boundary',
    () async {
      expect(
        await logic.saveSiswa(
          isEdit: true,
          siswaId: 1,
          nis: '001',
          nama: 'Student 1',
          kelasId: 2,
          ortuNama: 'Parent 1',
          ortuNomor: '',
          status: 'aktif',
        ),
        isNull,
      );
      await expectClasses([], [1, 2]);
    },
  );

  test('graduating one student removes them from the active cache', () async {
    expect(await logic.updateStatusSiswa(1, 'lulus'), isNull);
    await expectClasses([], [2]);
  });

  test('reactivating a student adds them back to the active cache', () async {
    await logic.updateStatusSiswa(1, 'lulus');
    await expectClasses([], [2]);
    expect(await logic.updateStatusSiswa(1, 'aktif'), isNull);
    await expectClasses([1], [2]);
  });

  test('bulk promotion invalidates both classes', () async {
    await logic.prosesKenaikanKelas(
      sourceKelasId: 1,
      targetKelasId: 2,
      isLuluskan: false,
    );
    await expectClasses([], [1, 2]);
  });

  test('bulk graduation removes active students from cache', () async {
    await logic.prosesKenaikanKelas(sourceKelasId: 1, isLuluskan: true);
    await expectClasses([], [2]);
  });

  test(
    'bulk promotion leaves inactive students in their original class',
    () async {
      store.students.add({
        'id': 3,
        'nis': '003',
        'nama': 'Graduate',
        'kelas_id': 1,
        'status': 'lulus',
      });
      await logic.prosesKenaikanKelas(
        sourceKelasId: 1,
        targetKelasId: 2,
        isLuluskan: false,
      );
      await expectClasses([], [1, 2]);
      expect(store.students.singleWhere((s) => s['id'] == 3)['kelas_id'], 1);
    },
  );

  test(
    'importing an existing NIS invalidates the old and new classes',
    () async {
      await repository.upsertSiswa([
        {
          'nis': '001',
          'nama': 'Student 1 imported',
          'kelas_id': 2,
          'status': 'aktif',
        },
      ]);
      await expectClasses([], [1, 2]);
      expect(
        (await cache.getActiveSiswaByKelas(2)).first['nama'],
        'Student 1 imported',
      );
    },
  );

  test('empty imports do not invalidate populated caches', () async {
    final readsBefore = store.reads;
    await repository.upsertSiswa([]);
    await expectClasses([1], [2]);
    expect(store.reads, readsBefore);
  });

  test('controller create invalidates the destination cache', () async {
    expect(
      await logic.saveSiswa(
        isEdit: false,
        nis: '003',
        nama: 'Student 3',
        kelasId: 2,
        ortuNama: 'Parent 3',
        ortuNomor: '',
        status: 'aktif',
      ),
      isNull,
    );
    await expectClasses([1], [2, 3]);
  });

  test('controller delete invalidates the populated cache', () async {
    expect(await logic.deleteSiswa(1), isNull);
    await expectClasses([], [2]);
  });

  test('failed writes preserve the cached data without refetching', () async {
    final readsBefore = store.reads;
    store.rejectWrites = true;
    expect(await logic.updateStatusSiswa(1, 'lulus'), isNotNull);
    await expectClasses([1], [2]);
    expect(store.reads, readsBefore);
  });
}

/// Local HTTP fixture: exercises real PostgREST queries without live credentials.
class _StudentStore {
  final students = <Map<String, dynamic>>[
    {
      'id': 1,
      'nis': '001',
      'nama': 'Student 1',
      'kelas_id': 1,
      'status': 'aktif',
    },
    {
      'id': 2,
      'nis': '002',
      'nama': 'Student 2',
      'kelas_id': 2,
      'status': 'aktif',
    },
  ];
  bool rejectWrites = false;
  int reads = 0;

  Future<http.Response> handle(http.Request request) async {
    if (request.url.path != '/rest/v1/siswa') {
      throw StateError('Unexpected fixture endpoint: ${request.url.path}');
    }
    final selected = students.where((student) {
      for (final column in ['id', 'kelas_id', 'status']) {
        final filter = request.url.queryParameters[column];
        if (filter != null && filter != 'eq.${student[column]}') return false;
      }
      return true;
    }).toList();

    if (request.method != 'GET' && rejectWrites) {
      return _response({
        'message': 'Write rejected by fixture',
        'code': '42501',
      }, 403);
    }
    switch (request.method) {
      case 'GET':
        reads++;
        return _response(selected, 200, count: selected.length);
      case 'PATCH':
        final updates = jsonDecode(request.body) as Map<String, dynamic>;
        for (final student in selected) {
          student.addAll(updates);
        }
        return _response(_representation(request, selected), 200);
      case 'POST':
        final decoded = jsonDecode(request.body);
        final batch = decoded is List ? decoded : [decoded];
        final written = <Map<String, dynamic>>[];
        for (final data in batch.cast<Map<String, dynamic>>()) {
          final existing = students
              .where((s) => s['nis'] == data['nis'])
              .firstOrNull;
          if (existing != null) {
            existing.addAll(data);
            written.add(existing);
          } else {
            final row = {'id': students.length + 1, 'status': 'aktif', ...data};
            students.add(row);
            written.add(row);
          }
        }
        return _response(_representation(request, written), 201);
      case 'DELETE':
        students.removeWhere(selected.contains);
        return _response(null, 200);
      default:
        throw StateError('Unexpected fixture method: ${request.method}');
    }
  }

  Object _representation(
    http.Request request,
    List<Map<String, dynamic>> rows,
  ) {
    return request.headers['Accept']?.contains('vnd.pgrst.object') == true ||
            request.headers['accept']?.contains('vnd.pgrst.object') == true
        ? rows.single
        : rows;
  }

  http.Response _response(Object? data, int status, {int? count}) =>
      http.Response(
        jsonEncode(data),
        status,
        headers: {
          'content-type': 'application/json',
          if (count != null)
            'content-range': count == 0 ? '*/0' : '0-${count - 1}/$count',
        },
      );
}
