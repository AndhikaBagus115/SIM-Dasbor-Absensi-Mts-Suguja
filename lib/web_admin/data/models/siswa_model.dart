import 'package:web_admin_mts/web_admin/core/constants.dart';

/// Model representing a student (Siswa)
class Siswa {
  final int id;
  final String nis;
  final String nama;
  final StudentStatus status;
  final String? kelasId;
  final String? email;
  final String? noHp;
  final String? alamat;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Siswa({
    required this.id,
    required this.nis,
    required this.nama,
    required this.status,
    this.kelasId,
    this.email,
    this.noHp,
    this.alamat,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create Siswa from JSON (typically from Supabase)
  factory Siswa.fromJson(Map<String, dynamic> json) {
    return Siswa(
      id: json[SiswaColumns.id] as int,
      nis: json[SiswaColumns.nis] as String? ?? '',
      nama: json[SiswaColumns.nama] as String? ?? '',
      status: StudentStatus.fromValue(
        json[SiswaColumns.status] as String? ?? 'aktif',
      ),
      kelasId: json[SiswaColumns.kelasId]?.toString(),
      email: json[SiswaColumns.email] as String?,
      noHp: json[SiswaColumns.noHp] as String?,
      alamat: json[SiswaColumns.alamat] as String?,
      createdAt: json[SiswaColumns.createdAt] != null
          ? DateTime.parse(json[SiswaColumns.createdAt] as String)
          : DateTime.now(),
      updatedAt: json[SiswaColumns.updatedAt] != null
          ? DateTime.parse(json[SiswaColumns.updatedAt] as String)
          : null,
    );
  }

  /// Convert Siswa to JSON for sending to Supabase
  Map<String, dynamic> toJson() => {
    SiswaColumns.id: id,
    SiswaColumns.nis: nis,
    SiswaColumns.nama: nama,
    SiswaColumns.status: status.value,
    SiswaColumns.kelasId: kelasId,
    SiswaColumns.email: email,
    SiswaColumns.noHp: noHp,
    SiswaColumns.alamat: alamat,
    SiswaColumns.createdAt: createdAt.toIso8601String(),
    SiswaColumns.updatedAt: updatedAt?.toIso8601String(),
  };

  /// Create a copy of this Siswa with some fields replaced
  Siswa copyWith({
    int? id,
    String? nis,
    String? nama,
    StudentStatus? status,
    String? kelasId,
    String? email,
    String? noHp,
    String? alamat,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Siswa(
      id: id ?? this.id,
      nis: nis ?? this.nis,
      nama: nama ?? this.nama,
      status: status ?? this.status,
      kelasId: kelasId ?? this.kelasId,
      email: email ?? this.email,
      noHp: noHp ?? this.noHp,
      alamat: alamat ?? this.alamat,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Siswa(id: $id, nis: $nis, nama: $nama, status: ${status.value})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Siswa &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nis == other.nis &&
          nama == other.nama;

  @override
  int get hashCode => id.hashCode ^ nis.hashCode ^ nama.hashCode;
}
