import '../../core/constants.dart';

/// Model representing an announcement (Pengumuman) sent to parents/students
class Pengumuman {
  final int id;
  final String judul;
  final String isi;
  final String targetTipe; // 'semua' | 'kelas' | 'siswa'
  final String? targetId;
  final String? targetNama;
  final DateTime createdAt;

  Pengumuman({
    required this.id,
    required this.judul,
    required this.isi,
    required this.targetTipe,
    this.targetId,
    this.targetNama,
    required this.createdAt,
  });

  /// Create Pengumuman from JSON (typically from Supabase)
  factory Pengumuman.fromJson(Map<String, dynamic> json) {
    return Pengumuman(
      id: (json[PengumumanColumns.id] as num?)?.toInt() ?? 0,
      judul: json[PengumumanColumns.judul] as String? ?? '',
      isi: json[PengumumanColumns.isi] as String? ?? '',
      targetTipe: json[PengumumanColumns.targetTipe] as String? ?? 'semua',
      targetId: json[PengumumanColumns.targetId]?.toString(),
      targetNama: json[PengumumanColumns.targetNama] as String?,
      createdAt: json[PengumumanColumns.createdAt] != null
          ? DateTime.parse(json[PengumumanColumns.createdAt] as String).toLocal()
          : DateTime.now(),
    );
  }

  /// Convert Pengumuman to JSON for sending to Supabase
  Map<String, dynamic> toJson({bool includeId = false}) => {
        if (includeId) PengumumanColumns.id: id,
        PengumumanColumns.judul: judul,
        PengumumanColumns.isi: isi,
        PengumumanColumns.targetTipe: targetTipe,
        PengumumanColumns.targetId: targetId,
        PengumumanColumns.targetNama: targetNama,
        PengumumanColumns.createdAt: createdAt.toUtc().toIso8601String(),
      };

  Pengumuman copyWith({
    int? id,
    String? judul,
    String? isi,
    String? targetTipe,
    String? targetId,
    String? targetNama,
    DateTime? createdAt,
  }) {
    return Pengumuman(
      id: id ?? this.id,
      judul: judul ?? this.judul,
      isi: isi ?? this.isi,
      targetTipe: targetTipe ?? this.targetTipe,
      targetId: targetId ?? this.targetId,
      targetNama: targetNama ?? this.targetNama,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Pengumuman(id: $id, judul: $judul, targetTipe: $targetTipe, targetNama: $targetNama)';
}
