/// Pemformat tanggal berbahasa Indonesia.
class DateFormatId {
  static const List<String> monthAbbreviations = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// Tanggal singkat waktu lokal, contoh "7 Nov 2026".
  static String short(DateTime date) {
    final local = date.toLocal();
    return '${local.day} ${monthAbbreviations[local.month - 1]} ${local.year}';
  }
}
