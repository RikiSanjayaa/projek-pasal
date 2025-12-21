class UndangUndangModel {
  final String id;

  final String kode;

  final String nama;

  final String? namaLengkap;

  final int tahun;

  final bool isActive;

  UndangUndangModel({
    required this.id,
    required this.kode,
    required this.nama,
    this.namaLengkap,
    required this.tahun,
    required this.isActive,
  });

  factory UndangUndangModel.fromJson(Map<String, dynamic> json) {
    return UndangUndangModel(
      id: json['id'] as String,
      kode: json['kode'] as String,
      nama: json['nama'] as String,
      namaLengkap: json['nama_lengkap'] as String?,
      tahun: json['tahun'] as int,
      isActive: json['is_active'] ?? true,
    );
  }
}
