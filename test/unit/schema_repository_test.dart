import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_admin_mts/web_admin/data/repositories/guru_repository.dart';
import 'package:web_admin_mts/web_admin/data/repositories/kelas_repository.dart';

void main() {
  const guruId = '55b1344c-7471-4e71-a767-3cd59e02ed7c';
  test('teacher repository uses the UUID in reads and writes', () async {
    final client = SupabaseClient(
      'https://fixture.test',
      'fixture-public',
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters['id'], 'eq.$guruId');
        if (request.method == 'PATCH') {
          expect(jsonDecode(request.body), {'nama': 'Diperbarui'});
        }
        return http.Response(
          jsonEncode({
            'id': guruId,
            'nama': 'Diperbarui',
            'email': 'guru@example.test',
            'role': 'guru',
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = GuruRepositoryImpl(client);
    expect((await repository.getGuruById(guruId))!.id, guruId);
    expect(
      (await repository.updateGuru(guruId, {'nama': 'Diperbarui'})).id,
      guruId,
    );
  });
  test(
    'class creation accepts real schema without a fictional tingkat column',
    () async {
      final client = SupabaseClient(
        'https://fixture.test',
        'fixture-public',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'nama_kelas': '7A',
            'wali_kelas': guruId,
          });
          return http.Response(
            jsonEncode({
              'id': 1,
              'nama_kelas': '7A',
              'wali_kelas': guruId,
              'jam_masuk': '07:00:00',
            }),
            201,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final kelas = await KelasRepositoryImpl(
        client,
      ).createKelas({'nama_kelas': '7A', 'wali_kelas': guruId});
      expect(kelas.waliKelasId, guruId);
    },
  );
}
