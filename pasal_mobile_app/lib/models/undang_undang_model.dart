class UndangUndangModel {
  final String id;

  final String kode;

  final String nama;

  final String? namaLengkap;

  final String? deskripsi;

  final int tahun;

  final bool isActive;

  final DateTime? updatedAt;

  UndangUndangModel({
    required this.id,
    required this.kode,
    required this.nama,
    this.namaLengkap,
    this.deskripsi,
    required this.tahun,
    required this.isActive,
    this.updatedAt,
  });

  factory UndangUndangModel.fromJson(Map<String, dynamic> json) {
    return UndangUndangModel(
      id: json['id'] as String,
      kode: json['kode'] as String,
      nama: json['nama'] as String,
      namaLengkap: json['nama_lengkap'] as String?,
      deskripsi: json['deskripsi'] as String?,
      // Handle null tahun with default value of 0
      tahun: (json['tahun'] as int?) ?? 0,
      isActive: json['is_active'] ?? true,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
