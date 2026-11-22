import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/report_export_service.dart';

/// Exports iterate until the exact count is reached, including server row caps.
class ReportRepository {
  ReportRepository(this.client);
  final SupabaseClient client;

  static Future<List<Map<String, dynamic>>> readAll(
    Future<PostgrestResponse> Function(int from, int to) fetch,
  ) async {
    final rows = <Map<String, dynamic>>[];
    int? total;
    do {
      final page = await fetch(rows.length, rows.length + 499);
      total ??= page.count;
      final data = List<Map<String, dynamic>>.from(page.data as List);
      if (data.isEmpty && rows.length < total) {
        throw StateError(
          'Data ekspor berubah atau tidak lengkap. Muat ulang lalu coba lagi.',
        );
      }
      rows.addAll(data);
    } while (rows.length < total);
    return rows;
  }

  Future<TabularReport> siswa({
    String? kelasId,
    String? status,
    String search = '',
  }) async {
    final rows = await readAll((from, to) {
      var query = client.from('siswa').select('*, kelas!inner(nama_kelas)');
      if (kelasId != null) query = query.eq('kelas_id', kelasId);
      if (status != null) query = query.eq('status', status);
      if (search.isNotEmpty) query = query.ilike('nama', '%$search%');
      return query.order('id').range(from, to).count(CountOption.exact);
    });
    return TabularReport(
      filename: 'siswa',
      headers: ['NIS', 'Nama', 'Kelas', 'Status', 'Nama Wali', 'Nomor Wali'],
      rows: rows
          .map(
            (row) => <Object?>[
              row['nis'],
              row['nama'],
              row['kelas']?['nama_kelas'],
              row['status'],
              row['orang_tua_nama'],
              row['orang_tua_nomor'],
            ],
          )
          .toList(),
    );
  }

  Future<TabularReport> guru() async {
    final rows = await readAll(
      (from, to) => client
          .from('guru')
          .select('id,nama,email,role,no_hp')
          .order('id')
          .range(from, to)
          .count(CountOption.exact),
    );
    return TabularReport(
      filename: 'guru',
      headers: ['Nama', 'Email', 'Role', 'No. HP'],
      rows: rows
          .map(
            (row) => <Object?>[
              row['nama'],
              row['email'],
              row['role'],
              row['no_hp'],
            ],
          )
          .toList(),
    );
  }

  Future<TabularReport> kelas() async {
    final rows = await readAll(
      (from, to) => client
          .from('kelas')
          .select('id,nama_kelas,jam_masuk,jam_pulang,guru(nama)')
          .order('id')
          .range(from, to)
          .count(CountOption.exact),
    );
    return TabularReport(
      filename: 'kelas',
      headers: ['Kelas', 'Wali Kelas', 'Jam Masuk', 'Jam Pulang'],
      rows: rows
          .map(
            (row) => <Object?>[
              row['nama_kelas'],
              row['guru']?['nama'],
              row['jam_masuk'],
              row['jam_pulang'],
            ],
          )
          .toList(),
    );
  }

  Future<List<Map<String, dynamic>>> dailyRows(
    DateTime date, {
    int? kelasId,
  }) => readAll((from, to) {
    var query = client
        .from('absensi')
        .select(
          '*, siswa!inner(nama,nis,kelas_id,status,kelas(nama_kelas)),guru:updated_by(nama)',
        )
        .eq('tanggal', DateFormat('yyyy-MM-dd').format(date))
        .eq('siswa.status', 'aktif');
    if (kelasId != null) query = query.eq('siswa.kelas_id', kelasId);
    return query.order('id').range(from, to).count(CountOption.exact);
  });

  Future<TabularReport> absensi(
    DateTime date, {
    int? kelasId,
    bool monthly = false,
  }) async {
    if (monthly) {
      final data = await readAll(
        (from, to) => client
            .rpc(
              'get_rekap_absensi',
              params: {
                'p_month': date.month,
                'p_year': date.year,
                'p_kelas_id': kelasId,
              },
            )
            .range(from, to)
            .count(CountOption.exact),
      );
      return TabularReport(
        filename: 'rekap_${DateFormat('yyyy-MM').format(date)}',
        headers: [
          'Nama',
          'Hadir',
          'Terlambat',
          'Sakit',
          'Izin',
          'Alfa',
          'Persentase',
        ],
        rows: data
            .map(
              (row) => <Object?>[
                row['nama_siswa'],
                row['hadir'],
                row['terlambat'],
                row['sakit'],
                row['izin'],
                row['alpha'],
                row['persentase'],
              ],
            )
            .toList(),
      );
    }
    final data = await dailyRows(date, kelasId: kelasId);
    return TabularReport(
      filename: 'absensi_${DateFormat('yyyy-MM-dd').format(date)}',
      headers: [
        'Tanggal',
        'NIS',
        'Nama',
        'Kelas',
        'Masuk',
        'Pulang',
        'Status',
        'Keterangan',
        'Diperbarui Oleh',
      ],
      rows: data
          .map(
            (row) => <Object?>[
              row['tanggal'],
              row['siswa']?['nis'],
              row['siswa']?['nama'],
              row['siswa']?['kelas']?['nama_kelas'],
              row['waktu_masuk'],
              row['waktu_pulang'],
              row['status'],
              row['keterangan'],
              row['guru']?['nama'],
            ],
          )
          .toList(),
    );
  }
}
