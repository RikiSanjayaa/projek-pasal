import 'package:flutter/material.dart';
import '../../core/services/data_service.dart';

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
    final textColor = isDark ? Colors.white : Colors.black87;

    if (query.isEmpty) {
      return Center(
        child: Text("Ketik kata kunci untuk mencari pasal...", style: TextStyle(color: textColor)),
      );
    }

    return FutureBuilder<List>(
      future: DataService.searchPasal(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("Tidak ditemukan hasil untuk '$query'", style: TextStyle(color: textColor)));
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
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isDark ? Colors.grey[800] : Colors.white,
                  child: ExpansionTile(
                    title: Column( 
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "$kodeUU - ",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                            Expanded(
                              child: _highlightText(pasal.nomor, query, isBold: true, isDark: isDark),
                            ),
                          ],
                        ),
                        if (pasal.judul != null) 
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: _highlightText(pasal.judul!, query, isBold: true, isDark: isDark),
                          ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: _highlightText(pasal.isi, query, isDark: isDark),
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _highlightText(pasal.isi, query, isDark: isDark),
                          
                          if (pasal.penjelasan != null && pasal.penjelasan!.isNotEmpty) ...[
                            const Divider(height: 24),
                            const Text("Penjelasan:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            _highlightText(pasal.penjelasan!, query, isDark: isDark),
                          ],

                          if (pasal.keywords.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: pasal.keywords.map((k) {
                                final bool isMatch = k.toLowerCase().contains(query.toLowerCase());
                                return Chip(
                                  label: _highlightText(k.toUpperCase(), query, isBold: true, isDark: isDark),
                                  backgroundColor: isMatch ? (isDark ? Colors.orange.withOpacity(0.3) : Colors.yellow.shade100) : (isDark ? Colors.grey[700] : Colors.grey.shade100),
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

  Widget _highlightText(String text, String query, {bool isBold = false, required bool isDark}) {
    if (query.isEmpty) {
      return Text(
        text, 
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87, 
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal
        )
      );
    }
    
    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final int index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          backgroundColor: isDark ? Colors.orange.withOpacity(0.5) : Colors.yellow.shade200,
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = index + query.length;
    }
    return RichText(text: TextSpan(children: spans));
  }
}