import 'package:material_ui/material_ui.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/query_service.dart';
import '../../models/pasal_model.dart';
import '../../models/pasal_link_model.dart';
import '../utils/highlight_text.dart';
import '../utils/uu_color_helper.dart';
import 'law_content_formatter.dart';

/// Widget displaying the "Penjelasan" (explanation) section for a Pasal
class PenjelasanSection extends StatelessWidget {
  final String penjelasan;
  final String searchQuery;

  const PenjelasanSection({
    super.key,
    required this.penjelasan,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    if (normalizeLegalDisplayText(penjelasan).length <= 3) {
      return const SizedBox.shrink();
    }
    final blocks = splitPenjelasanBlocks(penjelasan);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subTextColor = AppColors.textSecondary(isDark);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.5 : 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 14,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                'PENJELASAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final block in blocks) ...[
            if (block.label != null) ...[
              HighlightText(
                text: block.label!,
                query: searchQuery,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary.withValues(alpha: 0.9),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
            ],
            LawContentFormatter(
              content: block.body,
              searchQuery: searchQuery,
              fontSize: 15,
              height: 1.7,
              color: subTextColor,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Widget displaying related Pasal links
class RelatedPasalLinks extends StatelessWidget {
  final String pasalId;
  final void Function(PasalModel pasal) onNavigate;
  final IconData Function(String? kode) getUUIcon;

  const RelatedPasalLinks({
    super.key,
    required this.pasalId,
    required this.onNavigate,
    required this.getUUIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppColors.textPrimary(isDark);
    final subTextColor = AppColors.textSecondary(isDark);

    return FutureBuilder<List<PasalLinkWithTarget>>(
      future: QueryService.getPasalLinks(pasalId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final links = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link_rounded, size: 14, color: Colors.orange[400]),
                const SizedBox(width: 6),
                Text(
                  'PASAL TERKAIT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[400],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...links.map((link) {
              final relatedPasal = link.targetPasal;

              return FutureBuilder<String>(
                future: QueryService.getKodeUU(relatedPasal.undangUndangId),
                builder: (context, kodeSnapshot) {
                  final kodeUU = kodeSnapshot.data ?? "UU";
                  final relColor = UUColorHelper.getColor(kodeUU);

                  return GestureDetector(
                    onTap: () => onNavigate(relatedPasal),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(
                          alpha: isDark ? 0.1 : 0.05,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.withValues(
                            alpha: isDark ? 0.5 : 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: relColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              getUUIcon(kodeUU),
                              size: 16,
                              color: relColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "Pasal ${relatedPasal.nomor}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      kodeUU,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: relColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (link.keterangan != null &&
                                    link.keterangan!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    link.keterangan!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: subTextColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: subTextColor,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }
}
