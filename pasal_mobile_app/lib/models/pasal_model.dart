class PasalModel {
  final String id;
  final String undangUndangId;
  final String nomor;
  final String isi;
  final String? penjelasan;
  final String? judul;
  final String? bab;
  final List<String> relatedIds;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String verificationStatus;
  final DateTime? verifiedAt;

  static const String statusTerverifikasi = 'terverifikasi';
  static const String statusPerluVerifikasi = 'perlu_verifikasi';

  bool get isVerified => verificationStatus == statusTerverifikasi;

  PasalModel({
    required this.id,
    required this.undangUndangId,
    required this.nomor,
    required this.isi,
    this.penjelasan,
    this.judul,
    this.bab,
    this.relatedIds = const [],
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.verificationStatus = statusPerluVerifikasi,
    this.verifiedAt,
  });

  factory PasalModel.fromJson(Map<String, dynamic> json) {
    return PasalModel(
      id: json['id'] ?? '',
      undangUndangId: json['undang_undang_id'] ?? '',
      nomor: json['nomor'] ?? '',
      isi: json['isi'] ?? '',
      penjelasan: json['penjelasan'],
      judul: json['judul'],
      bab: json['bab'],
      relatedIds: json['related_ids'] != null
          ? List<String>.from(json['related_ids'])
          : [],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      verificationStatus: json['verification_status'] == statusTerverifikasi
          ? statusTerverifikasi
          : statusPerluVerifikasi,
      verifiedAt: DateTime.tryParse(json['verified_at']?.toString() ?? ''),
    );
  }
}
