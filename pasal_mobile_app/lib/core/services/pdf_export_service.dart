import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/pasal_model.dart';
import '../utils/search_utils.dart';

class PdfExportService {
  /// Exports a single article as PDF and opens print preview / download.
  static Future<void> exportSinglePasal({
    required PasalModel pasal,
    String searchQuery = '',
  }) async {
    final pdf = pw.Document();
    final terms = SearchUtils.highlightTerms(searchQuery);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'CariPasal - Dokumentasi Hukum',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    DateTime.now().toString().split(' ')[0],
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              // UU & Nomor
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  pasal.nomor.toLowerCase().startsWith('pasal')
                      ? pasal.nomor
                      : 'Pasal ${pasal.nomor}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),

              // Judul if any
              if (pasal.judul != null && pasal.judul!.trim().isNotEmpty) ...[
                pw.Text(
                  pasal.judul!,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
              ],

              // Content / Isi
              pw.Text(
                'Isi Pasal:',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              _buildHighlightText(pasal.isi, terms),
              pw.SizedBox(height: 14),

              // Penjelasan if any
              if (pasal.penjelasan != null && pasal.penjelasan!.trim().isNotEmpty) ...[
                pw.Text(
                  'Penjelasan:',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                _buildHighlightText(pasal.penjelasan!, terms),
              ],
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Pasal_${pasal.nomor.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Exports a list of articles from active search results as a consolidated PDF.
  static Future<void> exportBatchPasal({
    required List<PasalModel> pasalList,
    required String searchQuery,
  }) async {
    final pdf = pw.Document();
    final terms = SearchUtils.highlightTerms(searchQuery);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'CariPasal - Laporan Hasil Pencarian',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    'Kata Kunci: "$searchQuery"',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Ditemukan ${pasalList.length} pasal terkait pencarian "$searchQuery"',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 16),
            ...pasalList.map((pasal) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      pasal.nomor.toLowerCase().startsWith('pasal')
                          ? pasal.nomor
                          : 'Pasal ${pasal.nomor}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    if (pasal.judul != null && pasal.judul!.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        pasal.judul!,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 6),
                    _buildHighlightText(pasal.isi, terms),
                  ],
                ),
              );
            }).toList(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Hasil_Pencarian_${searchQuery.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _buildHighlightText(String text, List<String> terms) {
    if (terms.isEmpty) {
      return pw.Text(text, style: const pw.TextStyle(fontSize: 10));
    }

    final lowerText = text.toLowerCase();
    final spans = <pw.InlineSpan>[];
    int start = 0;

    while (start < text.length) {
      int bestIndex = -1;
      String bestTerm = '';

      for (final term in terms) {
        final index = lowerText.indexOf(term, start);
        if (index == -1) continue;
        if (bestIndex == -1 ||
            index < bestIndex ||
            (index == bestIndex && term.length > bestTerm.length)) {
          bestIndex = index;
          bestTerm = term;
        }
      }

      if (bestIndex == -1) {
        spans.add(pw.TextSpan(text: text.substring(start)));
        break;
      }

      if (bestIndex > start) {
        spans.add(pw.TextSpan(text: text.substring(start, bestIndex)));
      }

      spans.add(
        pw.WidgetSpan(
          child: pw.Container(
            color: PdfColors.yellow300,
            child: pw.Text(
              text.substring(bestIndex, bestIndex + bestTerm.length),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
      );

      start = bestIndex + bestTerm.length;
    }

    return pw.RichText(
      text: pw.TextSpan(
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
        children: spans,
      ),
    );
  }
}

