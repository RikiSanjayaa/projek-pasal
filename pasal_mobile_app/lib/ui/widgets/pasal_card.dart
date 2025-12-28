import 'package:flutter/material.dart';
import '../../models/pasal_model.dart';
import '../../core/services/data_service.dart';
import '../utils/highlight_text.dart';
import '../utils/image_helper.dart'; 
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
        
        final baseColor = ImageHelper.getBookColor(kodeUU);
        
        final cardBgColor = isDark 
            ? const Color(0xFF1E1E1E) 
            : baseColor.withOpacity(0.05); 

        final labelBgColor = isDark 
            ? Colors.white.withOpacity(0.1) 
            : baseColor.withOpacity(0.1);
            
        final labelTextColor = isDark 
            ? baseColor.withOpacity(0.8) 
            : baseColor;                 
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: cardBgColor, 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isDark ? BorderSide.none : BorderSide(color: baseColor.withOpacity(0.2)), 
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          color: isDark ? Colors.white70 : Colors.black87
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
                    style: TextStyle(color: subTextColor, fontSize: 13, height: 1.5),
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