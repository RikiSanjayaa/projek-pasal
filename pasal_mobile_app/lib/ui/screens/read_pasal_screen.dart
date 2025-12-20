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
        if (index < contextList!.length - 1) nextPasal = contextList![index + 1];
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          pasal.nomor.toLowerCase().startsWith("pasal") ? pasal.nomor : "Pasal ${pasal.nomor}",
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0,-2))]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            prevPasal != null
                ? ElevatedButton.icon(
                    onPressed: () => _navigate(context, prevPasal!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, 
                      foregroundColor: Colors.black,
                      elevation: 0,
                      side: const BorderSide(color: Colors.grey),
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
            HighlightText(
              text: pasal.isi,
              query: searchQuery,
              textAlign: TextAlign.justify,
              style: const TextStyle(
                fontSize: 16,
                height: 1.8, 
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 30),
            
            if (pasal.penjelasan != null && pasal.penjelasan!.length > 3) ...[
              const Divider(),
              const SizedBox(height: 10),
              const Text("PENJELASAN", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              HighlightText(
                text: pasal.penjelasan!,
                query: searchQuery,
                textAlign: TextAlign.justify,
                style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.grey),
              ),
              const SizedBox(height: 30),
            ],

            if (pasal.keywords.isNotEmpty) ...[
              const Divider(),
              const Text("Kata Kunci:", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pasal.keywords.map((k) => Chip(
                  label: Text(k, style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.blue.shade50,
                  side: BorderSide.none,
                  padding: const EdgeInsets.all(4),
                )).toList(),
              ),
              const SizedBox(height: 30),
            ],

            if (pasal.relatedIds.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 10),
              const Text("PASAL TERKAIT", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 8),
              ...pasal.relatedIds.map((relId) {
                final relatedPasal = DataService.getPasalById(relId);
                if (relatedPasal == null) return const SizedBox.shrink();

                return Card(
                  elevation: 0,
                  color: Colors.orange.shade50,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.link, color: Colors.orange),
                    title: Text("Pasal ${relatedPasal.nomor}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(DataService.getKodeUU(relatedPasal.undangUndangId), style: const TextStyle(fontSize: 10)),
                    trailing: const Icon(Icons.chevron_right, size: 16),
                    onTap: () {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => ReadPasalScreen(pasal: relatedPasal)));
                    },
                  ),
                );
              }).toList(),
            ]
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, PasalModel target) {
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => ReadPasalScreen(pasal: target, contextList: contextList))
    );
  }
}