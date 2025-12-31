import 'package:flutter/material.dart';
import '../../models/pasal_model.dart';
import '../../core/services/data_service.dart';
import '../utils/highlight_text.dart';

class ReadPasalScreen extends StatelessWidget {
  final PasalModel pasal;
  final String searchQuery;
  final List<PasalModel>? contextList;

  const ReadPasalScreen({
    super.key,
    required this.pasal,
    this.searchQuery = '',
    this.contextList,
  });

  @override
  Widget build(BuildContext context) {
    PasalModel? prevPasal;
    PasalModel? nextPasal;

    if (contextList != null && contextList!.isNotEmpty) {
      final index = contextList!.indexWhere((p) => p.id == pasal.id);
      if (index != -1) {
        if (index > 0) prevPasal = contextList![index - 1];
        if (index < contextList!.length - 1) {
          nextPasal = contextList![index + 1];
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          pasal.nomor.toLowerCase().startsWith("pasal")
              ? pasal.nomor
              : "Pasal ${pasal.nomor}",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            prevPasal != null
                ? ElevatedButton.icon(
                    onPressed: () => _navigate(context, prevPasal!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                      foregroundColor: isDark ? Colors.white : Colors.black,
                      elevation: 0,
                      side: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey,
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text("Sebelumnya"),
                  )
                : const SizedBox(width: 100),

            nextPasal != null
                ? ElevatedButton.icon(
                    onPressed: () => _navigate(context, nextPasal!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text("Selanjutnya"),
                  )
                : const SizedBox(width: 100),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pasal.judul != null) ...[
              HighlightText(
                text: pasal.judul!,
                query: searchQuery,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
            ],

            HighlightText(
              text: pasal.isi,
              query: searchQuery,
              textAlign: TextAlign.justify,
              style: TextStyle(fontSize: 16, height: 1.8, color: textColor),
            ),

            const SizedBox(height: 30),

            if (pasal.penjelasan != null && pasal.penjelasan!.length > 3) ...[
              Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
              const SizedBox(height: 10),
              const Text(
                "PENJELASAN",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              HighlightText(
                text: pasal.penjelasan!,
                query: searchQuery,
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: subTextColor,
                ),
              ),
              const SizedBox(height: 30),
            ],

            if (pasal.keywords.isNotEmpty) ...[
              Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
              Text(
                "Kata Kunci:",
                style: TextStyle(fontSize: 12, color: subTextColor),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pasal.keywords
                    .map(
                      (k) => Chip(
                        label: Text(
                          k,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : Colors.blue.shade50,
                        side: BorderSide.none,
                        padding: const EdgeInsets.all(4),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 30),
            ],

            if (pasal.relatedIds.isNotEmpty) ...[
              Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
              const SizedBox(height: 10),
              const Text(
                "PASAL TERKAIT",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              ...pasal.relatedIds.map((relId) {
                return FutureBuilder<PasalModel?>(
                  future: DataService.getPasalById(relId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const SizedBox.shrink();
                    }
                    final relatedPasal = snapshot.data!;

                    return FutureBuilder<String>(
                      future: DataService.getKodeUU(
                        relatedPasal.undangUndangId,
                      ),
                      builder: (context, kodeSnapshot) {
                        final kodeUU = kodeSnapshot.data ?? "UU";
                        return Card(
                          elevation: 0,
                          color: isDark
                              ? Colors.orange.withValues(alpha: 0.1)
                              : Colors.orange.shade50,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.link,
                              color: Colors.orange,
                            ),
                            title: Text(
                              "Pasal ${relatedPasal.nomor}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              kodeUU,
                              style: TextStyle(
                                fontSize: 10,
                                color: subTextColor,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: subTextColor,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReadPasalScreen(pasal: relatedPasal),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, PasalModel target) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReadPasalScreen(pasal: target, contextList: contextList),
      ),
    );
  }
}
