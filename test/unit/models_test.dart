import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin_mts/web_admin/core/constants.dart';
import 'package:web_admin_mts/web_admin/data/models/guru_model.dart';
import 'package:web_admin_mts/web_admin/data/models/kelas_model.dart';
import 'package:web_admin_mts/web_admin/data/models/pengumuman_model.dart';
import 'package:web_admin_mts/web_admin/data/models/siswa_model.dart';

void main() {
  group('Kelas Model Tests', () {
    test('Kelas fromJson and toJson works correctly', () {
      final json = {
        'id': 1,
        'nama_kelas': 'Kelas 7A',
        'tingkat': '7',
        'jam_masuk': '07:00',
        'jam_pulang': '13:00',
        'wali_kelas_id': 10,
        'jumlah_siswa': 30,
      };

      final kelas = Kelas.fromJson(json);
      expect(kelas.id, 1);
      expect(kelas.namaKelas, 'Kelas 7A');
      expect(kelas.tingkat, '7');
      expect(kelas.jamMasuk, '07:00');
      expect(kelas.jamPulang, '13:00');
      expect(kelas.waliKelasId, 10);
      expect(kelas.jumlahSiswa, 30);

      final serialized = kelas.toJson();
      expect(serialized['id'], 1);
      expect(serialized['nama_kelas'], 'Kelas 7A');
      expect(serialized['tingkat'], '7');
    });
  });

  group('Guru Model Tests', () {
    test('Guru fromJson and toJson works correctly', () {
      final json = {
        'id': 1,
        'nip': '198001012005011001',
        'nama': 'Ust. Ahmad Fauzi',
        'email': 'ahmad@mts.sch.id',
        'no_hp': '081234567890',
        'status': 'aktif',
        'foto_url': 'https://example.com/avatar.jpg',
      };

      final guru = Guru.fromJson(json);
      expect(guru.id, 1);
      expect(guru.nip, '198001012005011001');
      expect(guru.nama, 'Ust. Ahmad Fauzi');
      expect(guru.email, 'ahmad@mts.sch.id');
      expect(guru.noHp, '081234567890');
      expect(guru.status, 'aktif');
      expect(guru.fotoUrl, 'https://example.com/avatar.jpg');

      final serialized = guru.toJson();
      expect(serialized['id'], 1);
      expect(serialized['nama'], 'Ust. Ahmad Fauzi');
    });
  });

  group('Siswa Model Tests', () {
    test('Siswa fromJson and toJson works correctly', () {
      final json = {
        'id': 101,
        'nis': '2026001',
        'nama': 'Muhammad Rizki',
        'kelas_id': '1',
        'status': 'aktif',
        'no_hp': '08123456789',
      };

      final siswa = Siswa.fromJson(json);
      expect(siswa.id, 101);
      expect(siswa.nis, '2026001');
      expect(siswa.nama, 'Muhammad Rizki');
      expect(siswa.kelasId, '1');
      expect(siswa.status, StudentStatus.aktif);
      expect(siswa.noHp, '08123456789');

      final serialized = siswa.toJson();
      expect(serialized['nis'], '2026001');
      expect(serialized['status'], 'aktif');
    });
  });

  group('Pengumuman Model Tests', () {
    test('Pengumuman fromJson and toJson works correctly', () {
      final json = {
        'id': 50,
        'judul': 'Libur Awal Ramadhan',
        'isi': 'Diberitahukan bahwa KBM diliburkan.',
        'target_tipe': 'semua',
        'target_id': null,
        'target_nama': 'Semua Wali Murid',
        'created_at': '2026-03-01T08:00:00.000Z',
      };

      final pengumuman = Pengumuman.fromJson(json);
      expect(pengumuman.id, 50);
      expect(pengumuman.judul, 'Libur Awal Ramadhan');
      expect(pengumuman.targetTipe, 'semua');
      expect(pengumuman.targetNama, 'Semua Wali Murid');

      final serialized = pengumuman.toJson(includeId: true);
      expect(serialized['id'], 50);
      expect(serialized['judul'], 'Libur Awal Ramadhan');
    });
  });
}
