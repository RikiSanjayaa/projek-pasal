import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import '../../core/config/app_colors.dart';
import '../../core/utils/word_diff.dart';
import '../utils/highlight_text.dart';

/// Teks yang diakhiri kata rujukan (`ayat`, `huruf`, `angka`, `Pasal`) atau
/// daftar rujukan ("ayat (3) dan"), sehingga penanda berikutnya adalah isi
/// rujukan, bukan awal butir baru.
final RegExp _referenceTail = RegExp(
  r'(?:\b(?:ayat|huruf|angka|pasal)|\b(?:ayat|huruf|angka|pasal)\s+\(?[0-9a-z]+\)?\s+(?:dan|atau|serta|sampai\s+dengan|hingga))\s*$',
  caseSensitive: false,
);

bool _endsWithReference(String text) => _referenceTail.hasMatch(text);

String normalizeLegalDisplayText(String value) {
  final lines = value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAllMapped(
        RegExp(r'\b[a-z]\s+(?=[0-9]+[a-z]?\.\s+)', caseSensitive: false),
        (_) => '',
      )
      .replaceAllMapped(
        RegExp(
          r'[ \t]+((?:\((?:[0-9]+[a-z]?|[ivxlcdm]{1,4})\)|[0-9]+[a-z]?\.|\([a-z]\)|[a-z]\.)\s+)',
          caseSensitive: false,
        ),
        (match) {
          // Rujukan di tengah kalimat ("pada ayat (2) diterapkan") bukan butir.
          if (_endsWithReference(match.input.substring(0, match.start))) {
            return match.group(0)!;
          }
          return '\n${match.group(1)}';
        },
      )
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final blocks = <String>[];

  bool startsNewBlock(String line, String previous) {
    if (_endsWithReference(previous)) return false;
    return RegExp(
      r'^(Pasal|Nom[oe]r)\s+[0-9]|^(Penjelasan|Pendapat\s+Ahli|Catatan\s+Ahli)\s*:?|^(\((?:[0-9]+[a-z]?|[ivxlcdm]{1,4})\)|[0-9]+[a-z]?\.|\([a-z]\)|[a-z]\.)\s+',
      caseSensitive: false,
    ).hasMatch(line);
  }

  // A line that follows a finished sentence and starts with a capital letter
  // is a new paragraph, not a hard-wrapped continuation.
  bool startsNewParagraph(String previous, String line) {
    return RegExp(r'[.:;]$').hasMatch(previous) &&
        RegExp(r'^[A-Z"\u201C]').hasMatch(line);
  }

  for (final line in lines) {
    if (blocks.isEmpty ||
        startsNewBlock(line, blocks.last) ||
        startsNewParagraph(blocks.last, line)) {
      blocks.add(line);
    } else {
      blocks[blocks.length - 1] = '${blocks.last} $line'
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .trim();
    }
  }

  return blocks.join('\n').trim();
}

/// One explanation block of a Penjelasan, optionally introduced by a label
/// such as `Ayat (2)`, `Huruf b` or `Angka 3`.
class PenjelasanBlock {
  final String? label;
  final String body;

  const PenjelasanBlock({this.label, required this.body});
}

const String _penjelasanLabelSource =
    r'(?:Ayat\s+\([0-9]+[a-z]?\)|Huruf\s+[a-z]|Angka\s+[0-9]+[a-z]?)';
final RegExp _penjelasanLabelAtStart = RegExp(
  '^($_penjelasanLabelSource)(?=\\s|\$)',
);
final RegExp _penjelasanInlineLabel = RegExp(
  '([.:;!?])\\s+(?=$_penjelasanLabelSource\\s)',
);

/// Splits Penjelasan text into blocks at line-leading labels (`Ayat (1)`,
/// `Huruf a`, `Angka 1`). Text without a label stays in an unlabeled block.
List<PenjelasanBlock> splitPenjelasanBlocks(String value) {
  final lines = value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAllMapped(_penjelasanInlineLabel, (m) => '${m.group(1)}\n')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty);

  final blocks = <PenjelasanBlock>[];
  String? label;
  final body = <String>[];

  void flush() {
    if (label != null || body.isNotEmpty) {
      blocks.add(PenjelasanBlock(label: label, body: body.join('\n')));
    }
    label = null;
    body.clear();
  }

  for (final line in lines) {
    final match = _penjelasanLabelAtStart.firstMatch(line);
    if (match != null) {
      flush();
      label = match.group(1)!.replaceAll(RegExp(r'\s+'), ' ');
      final rest = line.substring(match.end).trim();
      if (rest.isNotEmpty) body.add(rest);
    } else {
      body.add(line);
    }
  }
  flush();
  return blocks;
}

TextAlign smartLegalTextAlign({
  required TextAlign requested,
  required String text,
  required double maxWidth,
  required double fontSize,
}) {
  if (requested != TextAlign.justify) return requested;
  if (!maxWidth.isFinite) return requested;

  final words = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  final wordCount = words.length;
  if (wordCount < 8) return TextAlign.left;

  final readableCharsPerLine = maxWidth / (fontSize * 0.56);
  final averageWordLength =
      text.replaceAll(RegExp(r'\s+'), '').length / wordCount;
  final estimatedWordsPerLine = readableCharsPerLine / (averageWordLength + 1);

  // Flutter does not hyphenate Indonesian text. On narrow phone columns,
  // forced justify creates large gaps, so use left alignment for those cases.
  if (maxWidth < 330 || estimatedWordsPerLine < 6) {
    return TextAlign.left;
  }

  return TextAlign.justify;
}

/// Word diff antara dua teks hukum. Kedua teks dinormalisasi dulu dengan
/// [normalizeLegalDisplayText] supaya struktur ayat/huruf sama dengan tampilan
/// baca, lalu hasilnya dirender oleh [LawContentFormatter.diff].
List<DiffSegment> diffLegalTexts(String oldText, String newText) {
  return WordDiff.compute(
    normalizeLegalDisplayText(oldText),
    normalizeLegalDisplayText(newText),
  );
}

class _DiffPaint {
  final Uint8List kinds;
  final bool isDark;

  const _DiffPaint(this.kinds, this.isDark);
}

const int _kindEqual = 0;
const int _kindInserted = 1;
const int _kindRemoved = 2;

int _leadingSpace(String s) => s.length - s.trimLeft().length;

class LawContentFormatter extends StatelessWidget {
  final String content;
  final String searchQuery;
  final double fontSize;
  final Color? color;
  final double height;
  final TextAlign textAlign;
  final double letterSpacing;
  final List<DiffSegment>? diffSegments;

  const LawContentFormatter({
    super.key,
    required this.content,
    this.searchQuery = '',
    this.fontSize = 14.0,
    this.color,
    this.height = 1.5,
    this.textAlign = TextAlign.justify,
    this.letterSpacing = 0,
  }) : diffSegments = null;

  /// Menampilkan [segments] (hasil [diffLegalTexts]): teks yang dihapus dicoret
  /// merah, teks yang disisipkan diberi latar hijau dan garis bawah. Struktur
  /// ayat/huruf dibentuk dari teks gabungan.
  const LawContentFormatter.diff({
    super.key,
    required List<DiffSegment> segments,
    this.fontSize = 14.0,
    this.color,
    this.height = 1.5,
    this.textAlign = TextAlign.justify,
    this.letterSpacing = 0,
  }) : diffSegments = segments,
       content = '',
       searchQuery = '';

  /// Teks gabungan dan jenis tiap karakternya (sama / disisipkan / dihapus).
  static (String, Uint8List) _mergeSegments(List<DiffSegment> segments) {
    final buffer = StringBuffer();
    final kinds = <int>[];
    void add(String text, int kind) {
      buffer.write(text);
      for (var i = 0; i < text.length; i++) {
        kinds.add(kind);
      }
    }

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      switch (seg.op) {
        case DiffOp.equal:
          add(seg.text, _kindEqual);
        case DiffOp.inserted:
          add(seg.text, _kindInserted);
        case DiffOp.removed:
          add(seg.text, _kindRemoved);
          // Pemisah agar teks dihapus dan pengganti tidak menempel.
          final next = i + 1 < segments.length ? segments[i + 1] : null;
          if (next != null &&
              next.op == DiffOp.inserted &&
              !RegExp(r'\s$').hasMatch(seg.text) &&
              !next.text.startsWith(RegExp(r'\s'))) {
            add(' ', _kindEqual);
          }
      }
    }
    return (buffer.toString(), Uint8List.fromList(kinds));
  }

  @override
  Widget build(BuildContext context) {
    _DiffPaint? paint;
    String normalizedContent;
    final segments = diffSegments;
    if (segments != null) {
      final (merged, kinds) = _mergeSegments(segments);
      normalizedContent = merged.trim();
      if (normalizedContent.isEmpty) return const SizedBox.shrink();
      final lead = _leadingSpace(merged);
      paint = _DiffPaint(
        Uint8List.sublistView(kinds, lead, lead + normalizedContent.length),
        Theme.of(context).brightness == Brightness.dark,
      );
    } else {
      if (content.isEmpty) return const SizedBox.shrink();
      normalizedContent = normalizeLegalDisplayText(content);
      if (normalizedContent.isEmpty) return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        // Regex matches markers like: (1), 1., a., (a), (2a), 2a.
        final RegExp pattern = RegExp(
          r'(?:^|[\.\:;!?\n])\s*((\(\d+[a-z]?\))|(\d+[a-z]?\.)|(\([a-z]\))|([a-z]\.))\s+',
          caseSensitive: false,
        );

        final List<Widget> children = [];

        final matches = pattern.allMatches(normalizedContent);

        if (matches.isEmpty) {
          if (normalizedContent.contains('\n')) {
            var pos = 0;
            final lines = <Widget>[];
            for (final line in normalizedContent.split('\n')) {
              lines.add(_buildParagraph(line, 0, maxWidth, pos, paint));
              pos += line.length + 1;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines,
            );
          }
          return _buildHighlightedParagraph(normalizedContent, maxWidth, paint);
        }

        // Handle Intro text
        final firstMatch = matches.first;
        final fullFirstMatchStr = normalizedContent.substring(
          firstMatch.start,
          firstMatch.end,
        );
        final firstMarkerStr = firstMatch.group(1)!;
        final firstMarkerAbsoluteStart =
            firstMatch.start + fullFirstMatchStr.indexOf(firstMarkerStr);

        String introText = normalizedContent.substring(
          0,
          firstMarkerAbsoluteStart,
        );
        if (introText.trim().isNotEmpty) {
          children.add(
            _buildParagraph(
              introText.trim(),
              0,
              maxWidth,
              _leadingSpace(introText),
              paint,
            ),
          );
        }

        // Loop through all matches
        for (int i = 0; i < matches.length; i++) {
          final match = matches.elementAt(i);

          final markerStr = match.group(1)!;
          final bodyStart = match.end;

          int bodyEnd = normalizedContent.length;

          if (i + 1 < matches.length) {
            final nextMatch = matches.elementAt(i + 1);
            final nextFullMatchStr = normalizedContent.substring(
              nextMatch.start,
              nextMatch.end,
            );
            final nextMarkerStr = nextMatch.group(1)!;
            bodyEnd = nextMatch.start + nextFullMatchStr.indexOf(nextMarkerStr);
          }

          String body = normalizedContent.substring(bodyStart, bodyEnd);

          // Calculate indent level based on marker type
          int indentLevel = 0;
          if (RegExp(r'^\(?\d+[a-z]?\)?\.?$').hasMatch(markerStr)) {
            // (1), 1., (2a), 2a.
            indentLevel = 0;
          } else if (RegExp(r'^\(?[a-z]\)?\.?$').hasMatch(markerStr)) {
            // (a), a.
            indentLevel = 1;
          }

          // Text after the first line break is a paragraph of its own, not
          // part of the list item.
          var linePos = bodyStart + _leadingSpace(body);
          final bodyLines = body.trim().split('\n');
          children.add(
            _buildListItem(
              markerStr,
              bodyLines.first,
              indentLevel,
              maxWidth,
              linePos,
              paint,
            ),
          );
          linePos += bodyLines.first.length + 1;
          for (final extra in bodyLines.skip(1)) {
            final extraStart = linePos + _leadingSpace(extra);
            linePos += extra.length + 1;
            if (extra.trim().isEmpty) continue;
            children.add(
              _buildParagraph(extra.trim(), 0, maxWidth, extraStart, paint),
            );
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  /// Teks biasa dengan highlight pencarian, atau teks berwarna diff bila
  /// [paint] ada. [start] adalah posisi [text] di teks gabungan.
  Widget _text(String text, int start, TextStyle style, TextAlign align, _DiffPaint? paint) {
    if (paint == null) {
      return HighlightText(
        text: text,
        query: searchQuery,
        style: style,
        textAlign: align,
      );
    }

    final spans = <TextSpan>[];
    var runStart = 0;
    while (runStart < text.length) {
      final kind = paint.kinds[start + runStart];
      var runEnd = runStart + 1;
      while (runEnd < text.length && paint.kinds[start + runEnd] == kind) {
        runEnd++;
      }
      final chunk = text.substring(runStart, runEnd);
      spans.add(switch (kind) {
        _kindInserted => TextSpan(
          text: chunk,
          style: TextStyle(
            color: AppColors.diffInserted(paint.isDark),
            backgroundColor: AppColors.diffInsertedBg(paint.isDark),
            decoration: TextDecoration.underline,
            decorationColor: AppColors.diffInserted(paint.isDark),
          ),
        ),
        _kindRemoved => TextSpan(
          text: chunk,
          style: TextStyle(
            color: AppColors.diffRemoved(paint.isDark),
            backgroundColor: AppColors.diffRemovedBg(paint.isDark),
            decoration: TextDecoration.lineThrough,
            decorationColor: AppColors.diffRemoved(paint.isDark),
          ),
        ),
        _ => TextSpan(text: chunk),
      });
      runStart = runEnd;
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: align,
    );
  }

  TextStyle get _style => TextStyle(
    fontSize: fontSize,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  Widget _buildHighlightedParagraph(
    String text,
    double maxWidth,
    _DiffPaint? paint,
  ) {
    return _text(
      text,
      0,
      _style,
      smartLegalTextAlign(
        requested: textAlign,
        text: text,
        maxWidth: maxWidth,
        fontSize: fontSize,
      ),
      paint,
    );
  }

  Widget _buildParagraph(
    String text,
    int indentLevel,
    double maxWidth,
    int start,
    _DiffPaint? paint,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0, left: indentLevel * 16.0),
      child: _text(
        text,
        start,
        _style,
        smartLegalTextAlign(
          requested: textAlign,
          text: text,
          maxWidth: maxWidth - (indentLevel * 16.0),
          fontSize: fontSize,
        ),
        paint,
      ),
    );
  }

  Widget _buildListItem(
    String marker,
    String text,
    int indentLevel,
    double maxWidth,
    int start,
    _DiffPaint? paint,
  ) {
    const double baseLeftPadding = 0.0;
    const double indentWidth = 22.0;

    // Calculate width based on typical char width + buffer to prevent wrapping like "(2a" \n ")"
    final double markerWidth = (marker.length * 8.0) + 2.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 8.0,
        left: baseLeftPadding + (indentLevel * indentWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: markerWidth,
            child: Text(marker, style: _style),
          ),
          Expanded(
            child: _text(
              text,
              start,
              _style,
              smartLegalTextAlign(
                requested: textAlign,
                text: text,
                maxWidth: maxWidth - markerWidth - (indentLevel * indentWidth),
                fontSize: fontSize,
              ),
              paint,
            ),
          ),
        ],
      ),
    );
  }
}
