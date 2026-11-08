/// Satu versi isi pasal (riwayat perubahan). Versi dengan `urutan` tertinggi
/// adalah teks yang sedang berlaku.
class PasalVersiModel {
  final String id;
  final String pasalId;
  final int urutan;
  final String status;
  final String? sumber;
  final String? judulSumber;
  final String? diundangkan;
  final String? berlakuSejak;
  final String? naskahResmi;
  final String isi;
  final String? penjelasan;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const String statusAsli = 'asli';
  static const String statusDiubah = 'diubah';
  static const String statusDisisipkan = 'disisipkan';
  static const String statusDihapus = 'dihapus';

  PasalVersiModel({
    required this.id,
    required this.pasalId,
    required this.urutan,
    required this.status,
    this.sumber,
    this.judulSumber,
    this.diundangkan,
    this.berlakuSejak,
    this.naskahResmi,
    required this.isi,
    this.penjelasan,
    this.createdAt,
    this.updatedAt,
  });

  factory PasalVersiModel.fromJson(Map<String, dynamic> json) {
    return PasalVersiModel(
      id: json['id']?.toString() ?? '',
      pasalId: json['pasal_id']?.toString() ?? '',
      urutan: (json['urutan'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? statusAsli,
      sumber: json['sumber'],
      judulSumber: json['judul_sumber'],
      diundangkan: json['diundangkan'],
      berlakuSejak: json['berlaku_sejak'],
      naskahResmi: json['naskah_resmi'],
      isi: json['isi'] ?? '',
      penjelasan: json['penjelasan'],
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  /// Tanggal "YYYY-MM-DD" dari server, atau null bila kosong/tidak valid.
  static DateTime? parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value);

  DateTime? get diundangkanDate => parseDate(diundangkan);
  DateTime? get berlakuSejakDate => parseDate(berlakuSejak);

  /// Label status untuk chip/daftar, contoh "Diubah".
  String get statusLabel => switch (status) {
    statusAsli => 'Asli',
    statusDiubah => 'Diubah',
    statusDisisipkan => 'Disisipkan',
    statusDihapus => 'Dihapus',
    _ => status,
  };
}
