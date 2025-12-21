class PasalModel {
  final String id;
  final String undangUndangId;
  final String nomor;
  final String isi;
  final String? penjelasan;
  final String? judul;
  final List<String> keywords;
  final List<String> relatedIds;
  final DateTime? createdAt;
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
      keywords: json['keywords'] != null
          ? List<String>.from(json['keywords'])
          : [],
      relatedIds: json['related_ids'] != null
          ? List<String>.from(json['related_ids'])
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
