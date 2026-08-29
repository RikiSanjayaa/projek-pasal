import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/pasal_model.dart';
import '../../ui/widgets/law_content_formatter.dart';
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
              ..._buildFormattedContent(pasal.isi, terms),
              pw.SizedBox(height: 14),

              // Penjelasan if any
              if (pasal.penjelasan != null && pasal.penjelasan!.trim().isNotEmpty) ...[
                pw.Text(
                  'Penjelasan:',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                ..._buildFormattedContent(pasal.penjelasan!, terms),
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
            pw.Center(
              child: pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Text(
                  'Ditemukan ${pasalList.length} pasal terkait pencarian "$searchQuery"',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            ...pasalList.map((pasal) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
                  ),
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
                    ..._buildFormattedContent(pasal.isi, terms),
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

  static List<pw.Widget> _buildFormattedContent(String content, List<String> terms) {
    if (content.isEmpty) return [];

    final normalized = normalizeLegalDisplayText(content);
    final RegExp pattern = RegExp(
      r'(?:^|[\.\:;!?\n])\s*((\(\d+[a-z]?\))|(\d+[a-z]?\.)|(\([a-z]\))|([a-z]\.))\s+',
      caseSensitive: false,
    );

    final matches = pattern.allMatches(normalized);
    if (matches.isEmpty) {
      return [_buildHighlightText(normalized, terms)];
    }

    final List<pw.Widget> widgets = [];
    final firstMatch = matches.first;
    final fullFirstMatchStr = normalized.substring(firstMatch.start, firstMatch.end);
    final firstMarkerStr = firstMatch.group(1)!;
    final firstMarkerAbsoluteStart = firstMatch.start + fullFirstMatchStr.indexOf(firstMarkerStr);

    String introText = normalized.substring(0, firstMarkerAbsoluteStart);
    if (introText.trim().isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: _buildHighlightText(introText.trim(), terms),
        ),
      );
    }

    for (int i = 0; i < matches.length; i++) {
      final match = matches.elementAt(i);
      final markerStr = match.group(1)!;
      final bodyStart = match.end;

      int bodyEnd = normalized.length;
      if (i + 1 < matches.length) {
        final nextMatch = matches.elementAt(i + 1);
        final nextFullMatchStr = normalized.substring(nextMatch.start, nextMatch.end);
        final nextMarkerStr = nextMatch.group(1)!;
        bodyEnd = nextMatch.start + nextFullMatchStr.indexOf(nextMarkerStr);
      }

      String body = normalized.substring(bodyStart, bodyEnd);
      double indent = 0;
      if (RegExp(r'^\(?[a-z]\)?\.?$').hasMatch(markerStr)) {
        indent = 12;
      }

      widgets.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 6, left: indent),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 28,
                child: pw.Text(
                  markerStr,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Expanded(
                child: _buildHighlightText(body.trim(), terms),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  static pw.Widget _buildHighlightText(String text, List<String> terms) {

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
        pw.TextSpan(
          text: text.substring(bestIndex, bestIndex + bestTerm.length),
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            background: const pw.BoxDecoration(color: PdfColors.yellow300),
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

