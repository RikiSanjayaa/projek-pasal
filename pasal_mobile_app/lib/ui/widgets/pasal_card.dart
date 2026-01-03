import 'package:flutter/material.dart';
import '../../models/pasal_model.dart';
import '../../core/services/data_service.dart';
import '../utils/highlight_text.dart';
import '../screens/read_pasal_screen.dart';

class PasalCard extends StatelessWidget {
  final PasalModel pasal;
  final String searchQuery;
  final List<PasalModel> contextList;
  final bool showUULabel;

  const PasalCard({
    super.key,
    required this.pasal,
    required this.contextList,
    this.searchQuery = '',
    this.showUULabel = true,
  });

  // Color presets (same as library_screen)
  static const List<Color> _presetColors = [
    Color(0xFFDC2626), // Red - KUHP
    Color(0xFF2563EB), // Blue - KUHAP
    Color(0xFF059669), // Emerald - ITE
    Color(0xFFD97706), // Amber - KUHPER
    Color(0xFF7C3AED), // Violet
    Color(0xFFDB2777), // Pink
    Color(0xFF0891B2), // Cyan
    Color(0xFF4F46E5), // Indigo
  ];

  Color _getUUColor(String kode) {
    final code = kode.toUpperCase().trim();
    if (code.contains('KUHPER') || code.contains('PERDATA')) {
      return _presetColors[3]; // Amber
    }
    if (code.contains('KUHAP')) {
      return _presetColors[1]; // Blue
    }
    if (code == 'KUHP' || code.startsWith('KUHP ')) {
      return _presetColors[0]; // Red
    }
    if (code.contains('ITE')) {
      return _presetColors[2]; // Emerald
    }
    // Generate from hash for unknown
    final hash = code.hashCode.abs();
    return _presetColors[hash % _presetColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final displayNomor = pasal.nomor.toLowerCase().startsWith('pasal')
        ? pasal.nomor
        : "Pasal ${pasal.nomor}";

    return FutureBuilder<String>(
      future: DataService.getKodeUU(pasal.undangUndangId),
      builder: (context, snapshot) {
        final kodeUU = snapshot.data ?? "UU";

        final baseColor = _getUUColor(kodeUU);

        final cardBgColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.8);

        final labelBgColor = isDark
            ? baseColor.withValues(alpha: 0.6)
            : baseColor.withValues(alpha: 0.1);

        final labelTextColor = isDark
            ? Colors.white.withValues(alpha: 0.8)
            : baseColor;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: cardBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReadPasalScreen(
                    pasal: pasal,
                    contextList: contextList,
                    searchQuery: searchQuery,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showUULabel) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: labelBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        kodeUU,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: labelTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Text(
                    displayNomor,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),

                  if (pasal.judul != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        pasal.judul!,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),

                  const SizedBox(height: 6),

                  HighlightText(
                    text: pasal.isi.replaceAll('\n', ' '),
                    query: searchQuery,
                    textAlign: TextAlign.left,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
