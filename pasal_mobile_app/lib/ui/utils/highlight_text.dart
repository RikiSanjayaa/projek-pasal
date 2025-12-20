import 'package:flutter/material.dart';

class HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final TextAlign textAlign;

  const HighlightText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    this.textAlign = TextAlign.start, 
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text, 
        style: style, 
        textAlign: textAlign,
      );
    }

    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    final List<TextSpan> spans = [];
    int start = 0;
    int indexOfHighlight = lowerText.indexOf(lowerQuery);

    while (indexOfHighlight != -1) {
      if (indexOfHighlight > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfHighlight), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(indexOfHighlight, indexOfHighlight + query.length),
        style: style.copyWith(backgroundColor: Colors.yellow, color: Colors.black),
      ));
      start = indexOfHighlight + query.length;
      indexOfHighlight = lowerText.indexOf(lowerQuery, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: textAlign,
    );
  }
}