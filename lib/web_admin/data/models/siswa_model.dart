import 'package:web_admin_mts/web_admin/core/constants.dart';

/// Model representing a student (Siswa)
class Siswa {
  final int id;
  final String nis;
  final String nama;
  final StudentStatus status;
  final String? kelasId;
  final String? orangTuaNama;
  final String? orangTuaNomor;
  final DateTime createdAt;

  Siswa({
    required this.id,
    required this.nis,
    required this.nama,
    required this.status,
    this.kelasId,
    this.orangTuaNama,
    this.orangTuaNomor,
    required this.createdAt,
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
      orangTuaNama: json[SiswaColumns.orangTuaNama] as String?,
      orangTuaNomor: json[SiswaColumns.orangTuaNomor] as String?,
      createdAt: json[SiswaColumns.createdAt] != null
          ? DateTime.parse(json[SiswaColumns.createdAt] as String)
          : DateTime.now(),
    );
  }

  /// Convert Siswa to JSON for sending to Supabase
  Map<String, dynamic> toJson() => {
    SiswaColumns.id: id,
    SiswaColumns.nis: nis,
    SiswaColumns.nama: nama,
    SiswaColumns.status: status.value,
    SiswaColumns.kelasId: kelasId == null ? null : int.parse(kelasId!),
    SiswaColumns.orangTuaNama: orangTuaNama,
    SiswaColumns.orangTuaNomor: orangTuaNomor,
    SiswaColumns.createdAt: createdAt.toIso8601String(),
  };

  /// Create a copy of this Siswa with some fields replaced
  Siswa copyWith({
    int? id,
    String? nis,
    String? nama,
    StudentStatus? status,
    String? kelasId,
    String? orangTuaNama,
    String? orangTuaNomor,
    DateTime? createdAt,
  }) {
    return Siswa(
      id: id ?? this.id,
      nis: nis ?? this.nis,
      nama: nama ?? this.nama,
      status: status ?? this.status,
      kelasId: kelasId ?? this.kelasId,
      orangTuaNama: orangTuaNama ?? this.orangTuaNama,
      orangTuaNomor: orangTuaNomor ?? this.orangTuaNomor,
      createdAt: createdAt ?? this.createdAt,
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
