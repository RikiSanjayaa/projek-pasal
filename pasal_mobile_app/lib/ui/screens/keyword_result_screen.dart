import 'package:flutter/material.dart';
import '../../core/services/data_service.dart';

class KeywordResultScreen extends StatelessWidget {
  final String keyword;

  const KeywordResultScreen({super.key, required this.keyword});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(keyword),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<List>(
        future: DataService.getPasalByKeyword(keyword),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("Tidak ada pasal dengan tag '$keyword'"));
          }

          final results = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final pasal = results[index];

              return FutureBuilder<String>(
                future: DataService.getKodeUU(pasal.undangUndangId),
                builder: (context, kodeSnapshot) {
                  final kodeUU = kodeSnapshot.data ?? "UU";

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        "$kodeUU - ${pasal.nomor}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        pasal.isi,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            pasal.isi,
                            textAlign: TextAlign.justify,
                            style: const TextStyle(height: 1.5),
                          ),
                        ),
                        if (pasal.keywords.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Wrap(
                              spacing: 8,
                              children: pasal.keywords.map((k) {
                                final isActive =
                                    k.toLowerCase() == keyword.toLowerCase();
                                return Chip(
                                  label: Text(
                                    k,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isActive
                                          ? Colors.white
                                          : Colors.blue,
                                    ),
                                  ),
                                  backgroundColor: isActive
                                      ? Colors.blue
                                      : Colors.white,
                                  side: BorderSide(
                                    color: isActive
                                        ? Colors.transparent
                                        : Colors.blue.shade100,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
