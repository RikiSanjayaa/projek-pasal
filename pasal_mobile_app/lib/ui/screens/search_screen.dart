import 'package:flutter/material.dart';
import '../../core/services/data_service.dart';

class PasalSearchDelegate extends SearchDelegate {
  
  @override
  String get searchFieldLabel => 'Cari kata kunci...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
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
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return const Center(child: Text("Ketik kata kunci untuk mencari pasal..."));
    }

    final results = DataService.searchPasal(query);

    if (results.isEmpty) {
      return Center(child: Text("Tidak ditemukan hasil untuk '$query'"));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final pasal = results[index];
        final kodeUU = DataService.getKodeUU(pasal.undangUndangId);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            title: Row(
              children: [
                Text("$kodeUU - ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                Expanded(child: _highlightText(pasal.nomor, query, isBold: true)),
              ],
            ),
            subtitle: _highlightText(pasal.isi, query),
            
            childrenPadding: const EdgeInsets.all(16),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _highlightText(pasal.isi, query),
                  if (pasal.penjelasan != null && pasal.penjelasan!.isNotEmpty) ...[
                     const Divider(height: 24),
                     const Text("Penjelasan:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                     const SizedBox(height: 4),
                     _highlightText(pasal.penjelasan!, query),
                  ],

                  if (pasal.keywords.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: pasal.keywords.map((k) {
                        final bool isMatch = k.toLowerCase().contains(query.toLowerCase());
                        return Chip(
                          label: _highlightText(k.toUpperCase(), query, isBold: true),
                          backgroundColor: isMatch ? Colors.yellow.shade100 : Colors.grey.shade100,
                          side: BorderSide(color: isMatch ? Colors.orange : Colors.grey.shade300),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    )
                  ]
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _highlightText(String text, String query, {bool isBold = false}) {
    if (query.isEmpty) return Text(text);
    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    int start = 0;
    
    while (true) {
      final int index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: text.substring(start), 
          style: TextStyle(color: Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)
        ));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: TextStyle(color: Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)
        ));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(backgroundColor: Colors.yellow.shade200, color: Colors.black, fontWeight: FontWeight.bold),
      ));
      start = index + query.length;
    }
    return RichText(text: TextSpan(children: spans));
  }
}