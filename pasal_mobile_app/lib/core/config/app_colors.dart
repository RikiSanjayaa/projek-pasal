import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors
  static const Color primary = Colors.blue;
  static const Color secondary = Colors.grey;

  // Backgrounds
  static const Color scaffoldLight = Color(0xFFF5F7FA);
  static const Color scaffoldDark = Color(0xFF121212);

  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E1E1E);

  static const Color inputFillLight = Colors.white;
  static const Color inputFillDark = Color(0xFF2C2C2C);

  static const Color appBarLight = Color(0xFFF5F7FA);
  static const Color appBarDark = Color(0xFF121212);

  static const Color bottomNavLight = Colors.white;
  static const Color bottomNavDark = Color(0xFF1E1E1E);

  // Text Colors
  static const Color textPrimaryLight = Colors.black87;
  static const Color textPrimaryDark = Colors.white;

  static const Color textSecondaryLight = Color(0xFF757575); // Colors.grey[600]
  static const Color textSecondaryDark = Color(0xFFBDBDBD); // Colors.grey[400]

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE0E0E0); // Colors.grey[300]
  static const Color borderDark = Color(0xFF616161); // Colors.grey[700]

  // Semantic Colors
  static const Color success = Colors.green;
  static const Color error = Colors.red;
  static const Color warning = Colors.orange;
  static const Color info = Colors.blue;

  // Icon Colors
  static const Color iconLight = Color(0xFF616161); // Colors.grey[700]
  static const Color iconDark = Color(0xFFE0E0E0); // Colors.grey[300]

  static const Color highlightLight = Color(0xFFFFF59D); // Colors.yellow[200]
  static const Color highlightDark = Color(0xFFFBC02D); // Colors.yellow[700]

  // Helper methods to get colors based on brightness
  static Color scaffold(bool isDark) => isDark ? scaffoldDark : scaffoldLight;
  static Color card(bool isDark) => isDark ? cardDark : cardLight;
  static Color textPrimary(bool isDark) =>
      isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) =>
      isDark ? textSecondaryDark : textSecondaryLight;
  static Color border(bool isDark) => isDark ? borderDark : borderLight;
  static Color bottomNav(bool isDark) =>
      isDark ? bottomNavDark : bottomNavLight;
  static Color appBar(bool isDark) => isDark ? appBarDark : appBarLight;
  static Color inputFill(bool isDark) =>
      isDark ? inputFillDark : inputFillLight;
  static Color icon(bool isDark) => isDark ? iconDark : iconLight;
  static Color highlight(bool isDark) =>
      isDark ? highlightDark : highlightLight;
}
