import '../../core/constants.dart';

/// Teacher IDs are the UUIDs of auth.users.
class Guru {
  final String id;
  final String nama;
  final String email;
  final String role;
  final dynamic kelasDiampu;
  final String? noHp;
  final String? avatarUrl;
  final String? fotoUrl;
  final DateTime? createdAt;

  Guru({
    required this.id,
    required this.nama,
    required this.email,
    this.role = 'guru',
    this.kelasDiampu,
    this.noHp,
    this.avatarUrl,
    this.fotoUrl,
    this.createdAt,
  });

  factory Guru.fromJson(Map<String, dynamic> json) => Guru(
    id: json[GuruColumns.id] as String,
    nama: json[GuruColumns.nama] as String,
    email: json[GuruColumns.email] as String,
    role: json[GuruColumns.role] as String? ?? 'guru',
    kelasDiampu: json[GuruColumns.kelasDiampu],
    noHp: json[GuruColumns.noHp] as String?,
    avatarUrl: json[GuruColumns.avatarUrl] as String?,
    fotoUrl: json[GuruColumns.fotoUrl] as String?,
    createdAt: DateTime.tryParse(json[GuruColumns.createdAt]?.toString() ?? ''),
  );

  Map<String, dynamic> toJson() => {
    GuruColumns.id: id,
    GuruColumns.nama: nama,
    GuruColumns.email: email,
    GuruColumns.role: role,
    GuruColumns.kelasDiampu: kelasDiampu,
    GuruColumns.noHp: noHp,
    GuruColumns.avatarUrl: avatarUrl,
    GuruColumns.fotoUrl: fotoUrl,
    if (createdAt != null) GuruColumns.createdAt: createdAt!.toIso8601String(),
  };

  Guru copyWith({
    String? id,
    String? nama,
    String? email,
    String? role,
    dynamic kelasDiampu,
    String? noHp,
    String? avatarUrl,
    String? fotoUrl,
    DateTime? createdAt,
  }) => Guru(
    id: id ?? this.id,
    nama: nama ?? this.nama,
    email: email ?? this.email,
    role: role ?? this.role,
    kelasDiampu: kelasDiampu ?? this.kelasDiampu,
    noHp: noHp ?? this.noHp,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    fotoUrl: fotoUrl ?? this.fotoUrl,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) => other is Guru && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
