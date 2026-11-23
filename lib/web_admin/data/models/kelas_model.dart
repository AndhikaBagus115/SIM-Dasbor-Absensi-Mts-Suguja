import '../../core/constants.dart';

class Kelas {
  final int id;
  final String namaKelas;
  final String? waliKelasId;
  final String jamMasuk;
  final String? jamPulang;
  final DateTime? createdAt;

  Kelas({
    required this.id,
    required this.namaKelas,
    this.waliKelasId,
    this.jamMasuk = '07:00:00',
    this.jamPulang,
    this.createdAt,
  });

  factory Kelas.fromJson(Map<String, dynamic> json) => Kelas(
    id: json[KelasColumns.id] as int,
    namaKelas: json[KelasColumns.namaKelas] as String,
    waliKelasId: json[KelasColumns.waliKelasId] as String?,
    jamMasuk: json[KelasColumns.jamMasuk] as String? ?? '07:00:00',
    jamPulang: json[KelasColumns.jamPulang] as String?,
    createdAt: DateTime.tryParse(
      json[KelasColumns.createdAt]?.toString() ?? '',
    ),
  );

  Map<String, dynamic> toJson() => {
    KelasColumns.id: id,
    KelasColumns.namaKelas: namaKelas,
    KelasColumns.waliKelasId: waliKelasId,
    KelasColumns.jamMasuk: jamMasuk,
    KelasColumns.jamPulang: jamPulang,
    if (createdAt != null) KelasColumns.createdAt: createdAt!.toIso8601String(),
  };

  Kelas copyWith({
    int? id,
    String? namaKelas,
    String? waliKelasId,
    String? jamMasuk,
    String? jamPulang,
    DateTime? createdAt,
  }) => Kelas(
    id: id ?? this.id,
    namaKelas: namaKelas ?? this.namaKelas,
    waliKelasId: waliKelasId ?? this.waliKelasId,
    jamMasuk: jamMasuk ?? this.jamMasuk,
    jamPulang: jamPulang ?? this.jamPulang,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) => other is Kelas && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
