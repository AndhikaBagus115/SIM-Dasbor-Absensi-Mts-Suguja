import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin_mts/web_admin/data/models/guru_model.dart';
import 'package:web_admin_mts/web_admin/data/models/kelas_model.dart';
import 'package:web_admin_mts/web_admin/data/models/surat_model.dart';
import 'package:web_admin_mts/web_admin/core/constants.dart';

void main() {
  const guruId = '55b1344c-7471-4e71-a767-3cd59e02ed7c';
  test(
    'Surat round-trips the actual jenis and nullable student/date fields',
    () {
      final letter = Surat.fromJson({
        'id': 1,
        'siswa_id': null,
        'jenis': 'sakit',
        'tanggal': '2026-11-22',
        'tanggal_selesai': '2026-11-23',
        'file_url': 'https://example.test/file',
        'status': 'menunggu',
        'catatan_guru': null,
      });
      expect(letter.tipe, LetterType.sakit);
      expect(letter.toJson()['tanggal_selesai'], '2026-11-23');
      expect(letter.toJson().keys, isNot(contains('tipe')));
      expect(letter.toJson().keys, isNot(contains('alasan')));
      expect(letter.toJson().keys, isNot(contains('updated_at')));
    },
  );
  test('Guru accepts the actual UUID primary key', () {
    final guru = Guru.fromJson({
      'id': guruId,
      'nama': 'Guru',
      'email': 'guru@example.test',
      'role': 'guru',
      'kelas_diampu': [1, 2],
    });
    expect(guru.id, guruId);
    expect(guru.toJson().keys, isNot(contains('nip')));
    expect(guru.toJson().keys, isNot(contains('status')));
    expect(guru.toJson()['role'], 'guru');
  });
  test('Kelas uses the UUID wali_kelas column and writes real columns', () {
    final kelas = Kelas.fromJson({
      'id': 1,
      'nama_kelas': '7A',
      'wali_kelas': guruId,
      'jam_masuk': '07:00:00',
      'jam_pulang': null,
    });
    expect(kelas.waliKelasId, guruId);
    expect(kelas.toJson()['wali_kelas'], guruId);
    expect(kelas.toJson().keys, isNot(contains('tingkat')));
    expect(kelas.toJson().keys, isNot(contains('jumlah_siswa')));
  });
}
