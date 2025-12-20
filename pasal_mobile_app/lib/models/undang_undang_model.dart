import 'package:hive/hive.dart';

part 'undang_undang_model.g.dart';

@HiveType(typeId: 0)
class UndangUndangModel extends HiveObject {
  @HiveField(0)
  final String id; 

  @HiveField(1)
  final String kode;

  @HiveField(2)
  final String nama;

  @HiveField(3)
  final String? namaLengkap;

  @HiveField(4)
  final int tahun;

  @HiveField(5)
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