import 'package:flutter/material.dart';
import '../utils/highlight_text.dart';

class LawContentFormatter extends StatelessWidget {
  final String content;
  final String searchQuery; // Added
  final double fontSize;
  final Color? color;
  final double height;

  const LawContentFormatter({
    super.key,
    required this.content,
    this.searchQuery = '', // Added
    this.fontSize = 14.0,
    this.color,
    this.height = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();

    // Normalize newlines
    final normalizedContent = content.replaceAll('\r\n', '\n');

    // Regex to identify list markers that start a new point.
    // Matches markers like "(1)", "1.", "a.", "(a)", "(2a)", "2a."
    // Considers markers at Start of String (with optional space) OR after Punctuation/Newline.
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
        style: TextStyle(fontSize: fontSize, color: color, height: height),
        textAlign: TextAlign.justify,
      );
    }

    // 1. Handle Intro text (before the first list item)
    final firstMatch = matches.first;
    final fullFirstMatchStr = normalizedContent.substring(
      firstMatch.start,
      firstMatch.end,
    );
    final firstMarkerStr = firstMatch.group(1)!;
    // Calculate the absolute start index of the actual marker within the content
    final firstMarkerAbsoluteStart =
        firstMatch.start + fullFirstMatchStr.indexOf(firstMarkerStr);

    String introText = normalizedContent.substring(0, firstMarkerAbsoluteStart);
    if (introText.trim().isNotEmpty) {
      children.add(_buildParagraph(introText.trim(), 0));
    }

    // 2. Loop through all matches to extract markers and their bodies
    for (int i = 0; i < matches.length; i++) {
      final match = matches.elementAt(i);

      final markerStr = match.group(1)!; // The actual marker, e.g., "(1)"

      // The body starts immediately after the current match's full extent (which includes trailing whitespace)
      final bodyStart = match.end;

      // Determine where the body ends: either at the start of the next marker, or end of content
      int bodyEnd = normalizedContent.length;

      if (i + 1 < matches.length) {
        final nextMatch = matches.elementAt(i + 1);
        final nextFullMatchStr = normalizedContent.substring(
          nextMatch.start,
          nextMatch.end,
        );
        final nextMarkerStr = nextMatch.group(1)!;
        // The body ends right before the next marker's actual start
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
        style: TextStyle(fontSize: fontSize, color: color, height: height),
      ),
    );
  }

  Widget _buildListItem(String marker, String text, int indentLevel) {
    // Base padding for list items
    const double baseLeftPadding = 0.0;
    const double indentWidth = 24.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 8.0,
        left: baseLeftPadding + (indentLevel * indentWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26, // Compact width (was 40), fits "1." or "(a)" well
            child: Text(
              marker,
              style: TextStyle(
                fontSize: fontSize,
                color: color,
                height: height,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: HighlightText(
              text: text,
              query: searchQuery,
              style: TextStyle(
                fontSize: fontSize,
                color: color,
                height: height,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }
}
