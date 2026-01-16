import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class AppShowcase extends StatelessWidget {
  final GlobalKey showcaseKey;
  final String title;
  final String description;
  final Widget child;
  final ShapeBorder? shapeBorder;

  const AppShowcase({
    super.key,
    required this.showcaseKey,
    required this.title,
    required this.description,
    required this.child,
    this.shapeBorder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final Color titleColor = isDark ? Colors.white : Colors.black;
    final Color descColor = isDark ? Colors.white70 : Colors.black87;

    return Showcase(
      key: showcaseKey,
      title: title,
      description: description,
      
      targetShapeBorder: shapeBorder ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),

      tooltipBackgroundColor: bgColor,
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: titleColor,
        height: 1.3,
      ),

      descTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: descColor,
        height: 1.4,
      ),

      overlayColor: Colors.black.withOpacity(0.7),
      
      blurValue: 1, 
      targetPadding: const EdgeInsets.all(4),

      child: child,
    );
  }
}