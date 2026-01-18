import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../models/pasal_model.dart';
import '../../core/services/query_service.dart';
import '../utils/highlight_text.dart';
import '../screens/read_pasal_screen.dart';
import '../utils/uu_color_helper.dart';

class PasalCard extends StatelessWidget {
  final PasalModel pasal;
  final String searchQuery;
  final List<PasalModel> contextList;
  final bool showUULabel;
  final List<String> matchedKeywords;

  const PasalCard({
    super.key,
    required this.pasal,
    required this.contextList,
    this.searchQuery = '',
    this.showUULabel = true,
    this.matchedKeywords = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppColors.textPrimary(isDark);
    final subTextColor = AppColors.textSecondary(isDark);

    final displayNomor =
        pasal.nomor.toLowerCase().startsWith('pasal')
            ? pasal.nomor
            : "Pasal ${pasal.nomor}";

    return FutureBuilder<String>(
      future: QueryService.getKodeUU(pasal.undangUndangId),
      builder: (context, snapshot) {
        final kodeUU = snapshot.data ?? "UU";

        final baseColor = UUColorHelper.getColor(kodeUU);

        final cardBgColor = AppColors.card(isDark);

        final labelBgColor =
            isDark
                ? baseColor.withValues(alpha: 0.6)
                : baseColor.withValues(alpha: 0.1);

        final labelTextColor =
            isDark ? Colors.white.withValues(alpha: 0.8) : baseColor;

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
                  builder:
                      (_) => ReadPasalScreen(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                      ],
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

                  if (pasal.judul != null &&
                      pasal.judul!.trim().isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        pasal.judul!,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ] else ...[
                    const SizedBox(height: 2),
                  ],
                  if (matchedKeywords.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children:
                          matchedKeywords.map((k) {
                            final chipColor = AppColors.primary.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            );
                            final chipTextColor = AppColors.primary;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: chipColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tag_rounded, 
                                    size: 10,
                                    color: chipTextColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    k,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: chipTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
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
