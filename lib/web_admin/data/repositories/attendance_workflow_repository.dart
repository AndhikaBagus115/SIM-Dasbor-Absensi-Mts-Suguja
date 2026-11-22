import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceWorkflowRepository {
  AttendanceWorkflowRepository(this.client);
  final SupabaseClient client;

  Future<List<String>> statusOptions() async {
    final data = await _request(() => client.rpc('attendance_status_options'));
    return List<String>.from(data as List);
  }

  Future<Map<String, dynamic>> reviewSurat(
    int id, {
    required bool approve,
    String? note,
  }) async {
    final data = await _request(
      () => client.rpc(
        'review_surat',
        params: {'p_id': id, 'p_approve': approve, 'p_note': note},
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> correct({
    required Map<String, dynamic> original,
    required String status,
    String? masuk,
    String? pulang,
    String? keterangan,
    required String reason,
  }) async {
    await _request(
      () => client.rpc(
        'correct_absensi',
        params: {
          'p_id': original['id'],
          'p_status': status,
          'p_waktu_masuk': masuk,
          'p_waktu_pulang': pulang,
          'p_keterangan': keterangan,
          'p_reason': reason,
          'p_expected': {
            for (final key in [
              'status',
              'waktu_masuk',
              'waktu_pulang',
              'keterangan',
              'updated_at',
            ])
              key: original[key],
          },
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> audit(int id) async {
    final data = await _request(
      () => client
          .from('absensi_audit')
          .select()
          .eq('absensi_id', id)
          .order('created_at', ascending: false)
          .limit(100),
    );
    return List<Map<String, dynamic>>.from(data);
  }

  Future<T> _request<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PostgrestException catch (e) {
      if (['PGRST202', 'PGRST205', '42883', '42P01'].contains(e.code)) {
        throw AttendanceWorkflowException(
          'Fitur ini belum diaktifkan di server. Hubungi pengelola aplikasi.',
        );
      }
      throw AttendanceWorkflowException(e.message);
    }
  }
}

class AttendanceWorkflowException implements Exception {
  AttendanceWorkflowException(this.message);
  final String message;
  @override
  String toString() => message;
}
