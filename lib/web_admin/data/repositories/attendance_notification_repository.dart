import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import 'report_repository.dart';

class AttendanceNotificationRepository {
  final SupabaseClient client;
  AttendanceNotificationRepository(this.client);

  Future<List<Map<String, dynamic>>> absentOn(String date) =>
      ReportRepository.readAll(
        (from, to) => client
            .from(DbTables.absensi)
            .select('siswa_id, siswa(id, nis, nama, orang_tua_nomor)')
            .eq(AbsensiColumns.tanggal, date)
            .eq(AbsensiColumns.status, AttendanceStatus.alfa.value)
            .order(AbsensiColumns.id)
            .range(from, to)
            .count(CountOption.exact),
      );
}
