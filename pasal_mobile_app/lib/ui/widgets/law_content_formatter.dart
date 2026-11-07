import 'package:material_ui/material_ui.dart';
import '../utils/highlight_text.dart';

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
        (match) => '\n${match.group(1)}',
      )
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final blocks = <String>[];

  bool startsNewBlock(String line) {
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
        startsNewBlock(line) ||
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

class LawContentFormatter extends StatelessWidget {
  final String content;
  final String searchQuery;
  final double fontSize;
  final Color? color;
  final double height;
  final TextAlign textAlign;
  final double letterSpacing;

  const LawContentFormatter({
    super.key,
    required this.content,
    this.searchQuery = '',
    this.fontSize = 14.0,
    this.color,
    this.height = 1.5,
    this.textAlign = TextAlign.justify,
    this.letterSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();

    final normalizedContent = normalizeLegalDisplayText(content);
    if (normalizedContent.isEmpty) return const SizedBox.shrink();

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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in normalizedContent.split('\n'))
                  _buildParagraph(line, 0, maxWidth),
              ],
            );
          }
          return _buildHighlightedParagraph(normalizedContent, maxWidth);
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
          children.add(_buildParagraph(introText.trim(), 0, maxWidth));
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
          final bodyLines = body.trim().split('\n');
          children.add(
            _buildListItem(markerStr, bodyLines.first, indentLevel, maxWidth),
          );
          for (final extra in bodyLines.skip(1)) {
            if (extra.trim().isEmpty) continue;
            children.add(_buildParagraph(extra.trim(), 0, maxWidth));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  Widget _buildHighlightedParagraph(String text, double maxWidth) {
    return HighlightText(
      text: text,
      query: searchQuery,
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      ),
      textAlign: smartLegalTextAlign(
        requested: textAlign,
        text: text,
        maxWidth: maxWidth,
        fontSize: fontSize,
      ),
    );
  }

  Widget _buildParagraph(String text, int indentLevel, double maxWidth) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0, left: indentLevel * 16.0),
      child: HighlightText(
        text: text,
        query: searchQuery,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        ),
        textAlign: smartLegalTextAlign(
          requested: textAlign,
          text: text,
          maxWidth: maxWidth - (indentLevel * 16.0),
          fontSize: fontSize,
        ),
      ),
    );
  }

  Widget _buildListItem(
    String marker,
    String text,
    int indentLevel,
    double maxWidth,
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
            child: Text(
              marker,
              style: TextStyle(
                fontSize: fontSize,
                color: color,
                height: height,
                letterSpacing: letterSpacing,
              ),
            ),
          ),
          Expanded(
            child: HighlightText(
              text: text,
              query: searchQuery,
              style: TextStyle(
                fontSize: fontSize,
                color: color,
                height: height,
                letterSpacing: letterSpacing,
              ),
              textAlign: smartLegalTextAlign(
                requested: textAlign,
                text: text,
                maxWidth: maxWidth - markerWidth - (indentLevel * indentWidth),
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
