import '../../core/constants.dart';

class Surat {
  final int id;
  final int? siswaId;
  final LetterType tipe;
  final DateTime tanggal;
  final DateTime? tanggalSelesai;
  final String? fileUrl;
  final String? status;
  final String? keterangan;
  final String? catatanGuru;
  final DateTime? createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  Surat({
    required this.id,
    this.siswaId,
    required this.tipe,
    required this.tanggal,
    this.tanggalSelesai,
    this.fileUrl,
    this.status,
    this.keterangan,
    this.catatanGuru,
    this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory Surat.fromJson(Map<String, dynamic> json) => Surat(
    id: json['id'] as int,
    siswaId: json['siswa_id'] as int?,
    tipe: LetterType.fromValue(json['jenis'] as String),
    tanggal: DateTime.parse(json['tanggal'] as String),
    tanggalSelesai: DateTime.tryParse(
      json['tanggal_selesai']?.toString() ?? '',
    ),
    fileUrl: json['file_url'] as String?,
    status: json['status'] as String?,
    keterangan: json['keterangan'] as String?,
    catatanGuru: json['catatan_guru'] as String?,
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    reviewedBy: json['reviewed_by'] as String?,
    reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
  );
  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'siswa_id': siswaId,
    'jenis': tipe.value,
    'tanggal': _date(tanggal),
    'tanggal_selesai': tanggalSelesai == null ? null : _date(tanggalSelesai!),
    'file_url': fileUrl,
    'status': status,
    'keterangan': keterangan,
    'catatan_guru': catatanGuru,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  @override
  bool operator ==(Object other) => other is Surat && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
