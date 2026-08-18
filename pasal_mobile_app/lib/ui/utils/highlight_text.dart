import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/utils/search_utils.dart';

class HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const HighlightText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final terms = SearchUtils.highlightTerms(query);
    if (terms.isEmpty) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String lowerText = text.toLowerCase();
    final List<TextSpan> spans = [];
    int start = 0;

    while (true) {
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
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }

      if (bestIndex > start) {
        spans.add(
          TextSpan(text: text.substring(start, bestIndex), style: style),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(bestIndex, bestIndex + bestTerm.length),
          style: (style ?? const TextStyle()).copyWith(
            backgroundColor: AppColors.highlight(isDark),
            color: Colors.black, // Always black on yellow highlight
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = bestIndex + bestTerm.length;
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
