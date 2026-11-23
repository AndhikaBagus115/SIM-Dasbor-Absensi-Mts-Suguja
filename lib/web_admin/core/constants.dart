// Only public configuration belongs in this client.
class AppConstants {
  static const schoolName = 'MTs Sunan Gunung Jati';
  static Map<String, dynamic> _public = {};

  static void loadPublicConfig(Map<String, dynamic> config) {
    const allowed = {'SUPABASE_URL', 'SUPABASE_ANON_KEY', 'APP_ENVIRONMENT'};
    if (config.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException(
        'Konfigurasi publik berisi field yang tidak diizinkan.',
      );
    }
    _public = Map.of(config);
  }

  static void initializeForWeb({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) {
    loadPublicConfig({
      'SUPABASE_URL': supabaseUrl,
      'SUPABASE_ANON_KEY': supabaseAnonKey,
    });
  }

  static String get supabaseUrl {
    const value = String.fromEnvironment('SUPABASE_URL');
    return value.isNotEmpty ? value : _required('SUPABASE_URL');
  }

  static String get supabaseAnonKey {
    const value = String.fromEnvironment('SUPABASE_ANON_KEY');
    return value.isNotEmpty ? value : _required('SUPABASE_ANON_KEY');
  }

  static String _required(String name) {
    final value = _public[name];
    if (value is! String || value.trim().isEmpty) {
      throw StateError(
        '$name belum dikonfigurasi. Jalankan tools/prepare_public_config.py.',
      );
    }
    return value;
  }

  static String get appEnvironment {
    const value = String.fromEnvironment('APP_ENVIRONMENT');
    return value.isNotEmpty
        ? value
        : (_public['APP_ENVIRONMENT'] as String? ?? 'development');
  }

  static bool get isProduction => appEnvironment == 'production';
  static bool get isDevelopment => appEnvironment == 'development';
}

// Database Table Names
abstract class DbTables {
  static const String siswa = 'siswa';
  static const String guru = 'guru';
  static const String kelas = 'kelas';
  static const String absensi = 'absensi';
  static const String surat = 'surat';
  static const String pengumuman = 'pengumuman';
}

// Database Column Names for Pengumuman
abstract class PengumumanColumns {
  static const String id = 'id';
  static const String judul = 'judul';
  static const String isi = 'isi';
  static const String targetTipe = 'target_tipe';
  static const String targetId = 'target_id';
  static const String targetNama = 'target_nama';
  static const String createdAt = 'created_at';
}

// Database Column Names for Siswa
abstract class SiswaColumns {
  static const String id = 'id';
  static const String nis = 'nis';
  static const String nama = 'nama';
  static const String status = 'status';
  static const String kelasId = 'kelas_id';
  static const String orangTuaNama = 'orang_tua_nama';
  static const String orangTuaNomor = 'orang_tua_nomor';
  static const String createdAt = 'created_at';
}

// Database Column Names for Guru
abstract class GuruColumns {
  static const String id = 'id';
  static const String role = 'role';
  static const String kelasDiampu = 'kelas_diampu';
  static const String avatarUrl = 'avatar_url';
  static const String nama = 'nama';
  static const String email = 'email';
  static const String noHp = 'no_hp';
  static const String fotoUrl = 'foto_url';
  static const String createdAt = 'created_at';
}

// Database Column Names for Kelas
abstract class KelasColumns {
  static const String id = 'id';
  static const String namaKelas = 'nama_kelas';
  static const String waliKelasId = 'wali_kelas';
  static const String jamMasuk = 'jam_masuk';
  static const String jamPulang = 'jam_pulang';
  static const String createdAt = 'created_at';
}

// Database Column Names for Absensi
abstract class AbsensiColumns {
  static const String id = 'id';
  static const String siswaId = 'siswa_id';
  static const String tanggal = 'tanggal';
  static const String status = 'status';
  static const String keterangan = 'keterangan';
  static const String waktuMasuk = 'waktu_masuk';
  static const String waktuPulang = 'waktu_pulang';
  static const String updatedBy = 'updated_by';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

// Database Column Names for Surat
abstract class SuratColumns {
  static const String id = 'id';
  static const String siswaId = 'siswa_id';
  static const String tipe = 'jenis';
  static const String tanggal = 'tanggal';
  static const String keterangan = 'keterangan';
  static const String createdAt = 'created_at';
  static const String tanggalSelesai = 'tanggal_selesai';
  static const String fileUrl = 'file_url';
  static const String status = 'status';
  static const String catatanGuru = 'catatan_guru';
}

// Student Status Enum
enum StudentStatus {
  aktif('aktif', 'Aktif'),
  lulus('lulus', 'Lulus'),
  pindah('pindah', 'Pindah'),
  keluar('keluar', 'Keluar');

  final String value;
  final String displayName;

  const StudentStatus(this.value, this.displayName);

  factory StudentStatus.fromValue(String value) {
    return StudentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => StudentStatus.aktif,
    );
  }
}

// Attendance Status Enum
enum AttendanceStatus {
  hadir('hadir', 'Hadir'),
  terlambat('terlambat', 'Terlambat'),
  sakit('sakit', 'Sakit'),
  izin('izin', 'Izin'),
  alfa('alfa', 'Alfa'),
  pulang('pulang', 'Pulang');

  final String value;
  final String displayName;

  const AttendanceStatus(this.value, this.displayName);

  factory AttendanceStatus.fromValue(String value) {
    return AttendanceStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => AttendanceStatus.hadir,
    );
  }

  /// Check if status indicates student is present
  bool get isPresent =>
      this == AttendanceStatus.hadir || this == AttendanceStatus.pulang;

  /// Check if status indicates student is absent
  bool get isAbsent =>
      this == AttendanceStatus.sakit ||
      this == AttendanceStatus.izin ||
      this == AttendanceStatus.alfa;

  /// Check if status indicates student is late
  bool get isLate => this == AttendanceStatus.terlambat;
}

// Letter Type Enum
enum LetterType {
  izin('izin', 'Izin'),
  sakit('sakit', 'Sakit');

  final String value;
  final String displayName;

  const LetterType(this.value, this.displayName);

  factory LetterType.fromValue(String value) {
    return LetterType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => LetterType.izin,
    );
  }
}

// GUI Status Color Mapping
abstract class StatusColors {
  static const Map<String, int> attendanceColors = {
    'hadir': 0xFF4CAF50, // Green
    'terlambat': 0xFFFFC107, // Amber
    'sakit': 0xFF2196F3, // Blue
    'izin': 0xFF9C27B0, // Purple
    'alfa': 0xFFF44336, // Red
    'pulang': 0xFF00BCD4, // Cyan
  };

  static const Map<String, int> studentStatusColors = {
    'aktif': 0xFF4CAF50, // Green
    'lulus': 0xFF2196F3, // Blue
    'pindah': 0xFFFF5722, // Deep Orange
    'keluar': 0xFF757575, // Grey
  };
}

// UI Constants
abstract class UiConstants {
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const int searchDebounceMs = 500;
  static const int paginationPageSize = 20;
}
