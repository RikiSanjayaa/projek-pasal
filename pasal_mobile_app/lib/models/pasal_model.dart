import 'package:hive/hive.dart';

part 'pasal_model.g.dart';

@HiveType(typeId: 1)
class PasalModel {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String undangUndangId;
  @HiveField(2)
  final String nomor;
  @HiveField(3)
  final String isi;
  @HiveField(4)
  final String? penjelasan;
  @HiveField(5)
  final String? judul;
  @HiveField(6)
  final List<String> keywords;
  @HiveField(7)
  final List<String> relatedIds;
  @HiveField(8)
  final DateTime? createdAt;
  
  @HiveField(9)
  final DateTime? updatedAt; 

  PasalModel({
    required this.id,
    required this.undangUndangId,
    required this.nomor,
    required this.isi,
    this.penjelasan,
    this.judul,
    this.keywords = const [],
    this.relatedIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory PasalModel.fromJson(Map<String, dynamic> json) {
    return PasalModel(
      id: json['id'] ?? '',
      undangUndangId: json['undang_undang_id'] ?? '',
      nomor: json['nomor'] ?? '',
      isi: json['isi'] ?? '',
      penjelasan: json['penjelasan'],
      judul: json['judul'],
      keywords: json['keywords'] != null ? List<String>.from(json['keywords']) : [],
      relatedIds: json['related_ids'] != null ? List<String>.from(json['related_ids']) : [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }
}