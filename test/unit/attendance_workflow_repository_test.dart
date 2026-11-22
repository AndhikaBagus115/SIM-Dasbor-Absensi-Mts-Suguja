import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_admin_mts/web_admin/data/repositories/attendance_workflow_repository.dart';

void main() {
  test(
    'correction sends a snapshot and reason; actor identity is server-owned',
    () async {
      late Map<String, dynamic> payload;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/correct_absensi');
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{}',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await AttendanceWorkflowRepository(client).correct(
        original: {
          'id': 7,
          'status': 'alfa',
          'updated_at': '2026-11-22T00:00:00Z',
        },
        status: 'hadir',
        masuk: '07:00',
        reason: 'Verified',
      );
      expect(payload['p_expected']['status'], 'alfa');
      expect(payload['p_reason'], 'Verified');
      expect(payload.containsKey('updated_by'), isFalse);
      expect(payload.containsKey('actor_id'), isFalse);
    },
  );
  test(
    'missing migration is explained without exposing SQL internals',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({'code': 'PGRST202', 'message': 'missing function'}),
            404,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        AttendanceWorkflowRepository(client).reviewSurat(1, approve: true),
        throwsA(
          isA<AttendanceWorkflowException>().having(
            (error) => error.message,
            'message',
            contains('belum diaktifkan'),
          ),
        ),
      );
    },
  );
}
