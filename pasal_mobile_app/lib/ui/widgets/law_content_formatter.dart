import 'package:flutter/material.dart';
import '../utils/highlight_text.dart';

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
    this.letterSpacing = -0.3,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();

    // Normalize newlines
    final normalizedContent = content.replaceAll('\r\n', '\n');

    // Regex matches markers like: (1), 1., a., (a), (2a), 2a.
    final RegExp pattern = RegExp(
      r'(?:^|[\.\:;!?\n])\s*((\(\d+[a-z]?\))|(\d+[a-z]?\.)|(\([a-z]\))|([a-z]\.))\s+',
      caseSensitive: false,
    );

    final List<Widget> children = [];

    final matches = pattern.allMatches(normalizedContent);

    if (matches.isEmpty) {
      return HighlightText(
        text: normalizedContent,
        query: searchQuery,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        ),
        textAlign: textAlign,
      );
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

    String introText = normalizedContent.substring(0, firstMarkerAbsoluteStart);
    if (introText.trim().isNotEmpty) {
      children.add(_buildParagraph(introText.trim(), 0));
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

      children.add(_buildListItem(markerStr, body.trim(), indentLevel));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildParagraph(String text, int indentLevel) {
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
        textAlign: textAlign,
      ),
    );
  }

  Widget _buildListItem(String marker, String text, int indentLevel) {
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
              textAlign: textAlign,
            ),
          ),
        ],
      ),
    );
  }
}
