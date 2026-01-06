import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/data_service.dart';
import '../utils/highlight_text.dart';

class PasalSearchDelegate extends SearchDelegate {
  @override
  String get searchFieldLabel => 'Cari kata kunci...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppColors.textPrimary(isDark);

    if (query.isEmpty) {
      return Center(
        child: Text(
          "Ketik kata kunci untuk mencari pasal...",
          style: TextStyle(color: textColor),
        ),
      );
    }

    return FutureBuilder<List>(
      future: DataService.searchPasal(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "Tidak ditemukan hasil untuk '$query'",
              style: TextStyle(color: textColor),
            ),
          );
        }

        final results = snapshot.data!;
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final pasal = results[index];
            return FutureBuilder<String>(
              future: DataService.getKodeUU(pasal.undangUndangId),
              builder: (context, kodeSnapshot) {
                final kodeUU = kodeSnapshot.data ?? "UU";

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: AppColors.card(isDark),
                  child: ExpansionTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "$kodeUU - ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Expanded(
                              child: HighlightText(
                                text: pasal.nomor,
                                query: query,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (pasal.judul != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: HighlightText(
                              text: pasal.judul!,
                              query: query,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: HighlightText(
                        text: pasal.isi,
                        query: query,
                        style: TextStyle(color: textColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HighlightText(
                            text: pasal.isi,
                            query: query,
                            style: TextStyle(color: textColor),
                          ),

                          if (pasal.penjelasan != null &&
                              pasal.penjelasan!.isNotEmpty) ...[
                            const Divider(height: 24),
                            Text(
                              "Penjelasan:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                            const SizedBox(height: 4),
                            HighlightText(
                              text: pasal.penjelasan!,
                              query: query,
                              style: TextStyle(color: textColor),
                            ),
                          ],

                          if (pasal.keywords.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: pasal.keywords.map((k) {
                                final bool isMatch = k.toLowerCase().contains(
                                  query.toLowerCase(),
                                );
                                return Chip(
                                  label: HighlightText(
                                    text: k.toUpperCase(),
                                    query: query,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  backgroundColor: isMatch
                                      ? AppColors.highlight(isDark)
                                      : AppColors.inputFill(isDark),
                                  side: BorderSide.none,
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
