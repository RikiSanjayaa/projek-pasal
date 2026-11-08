import 'package:material_ui/material_ui.dart';

import '../../core/utils/search_utils.dart';
import '../../models/pasal_model.dart';

/// Judul kelompok hasil pencarian beberapa kata: frasa persis, istilah terkait, semua kata
/// (tidak berurutan), atau sebagian kata. Tampil di atas kartu pertama tiap kelompok.
class SearchTierHeader extends StatelessWidget {
  final SearchResult result;
  final SearchMatchTier tier;

  const SearchTierHeader({super.key, required this.result, required this.tier});

  /// Judul untuk kartu ke-[index] di [items], atau null kalau kartu itu bukan awal kelompok.
  static SearchTierHeader? before(SearchResult? result, List<PasalModel> items, int index) {
    if (result == null) return null;
    final tier = result.tierOf(items[index]);
    if (tier == null) return null;
    if (index > 0 && result.tierOf(items[index - 1]) == tier) return null;
    return SearchTierHeader(result: result, tier: tier);
  }

  /// Kalimat di bawah jumlah hasil kalau kueri beberapa kata tidak ditemukan sebagai frasa utuh.
  static String? noPhraseNotice(SearchResult? result) {
    if (result == null || !result.isTiered || result.pasal.isEmpty || result.hasPhraseMatch) {
      return null;
    }
    return 'Tidak ada pasal yang memuat "${result.phrase}" persis.';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = result.tiers.values.where((t) => t == tier).length;
    final (icon, label) = switch (tier) {
      SearchMatchTier.phrase => (Icons.format_quote_rounded, 'Memuat frasa "${result.phrase}"'),
      SearchMatchTier.alias => (
        Icons.swap_horiz_rounded,
        'Memuat istilah terkait: ${result.aliases.join(', ')}',
      ),
      SearchMatchTier.allWords => (Icons.scatter_plot_outlined, 'Memuat semua kata, tidak berurutan'),
      SearchMatchTier.partial => (Icons.filter_list_rounded, 'Memuat sebagian kata'),
    };
    final color = isDark ? Colors.grey[400] : Colors.grey[700];
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label ($count)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
