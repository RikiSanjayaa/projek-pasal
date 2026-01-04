import 'package:flutter/material.dart';

class UUColorHelper {
  // Curated presets for specific known laws to ensure they always get their "brand" color
  static const Map<String, Color> _specificColors = {
    'KUHP': Color(0xFFDC2626), // Red
    'KUHAP': Color(0xFF2563EB), // Blue
    'ITE': Color(0xFF059669), // Emerald
    'KUHPER': Color(0xFFD97706), // Amber
    'PERDATA': Color(0xFFD97706), // Amber (Alias)
    'HAM': Color(0xFF7C3AED), // Violet
    'KORUPSI': Color(0xFFDB2777), // Pink
    'LALIN': Color(0xFF0891B2), // Cyan
    'NARKOTIKA': Color(0xFF4F46E5), // Indigo
  };

  // Fallback palette for unknown/dynamic UUs
  // Large enough to avoid repeats for small sets, distinct enough to be readable
  static const List<Color> _fallbackPalette = [
    Color(0xFFEA580C), // Orange
    Color(0xFF65A30D), // Lime
    Color(0xFF0D9488), // Teal
    Color(0xFF2563EB), // Blue
    Color(0xFF9333EA), // Purple
    Color(0xFFC026D3), // Fuchsia
    Color(0xFFE11D48), // Rose
    Color(0xFF4B5563), // Cool Grey
    Color(0xFFB45309), // Amber 700
    Color(0xFF15803D), // Green 700
  ];

  /// Get a consistent color for a given UU Code.
  /// Handles null, normalization, and infinite variations safely.
  static Color getColor(String? code) {
    if (code == null || code.trim().isEmpty) {
      return Colors.grey; // Default safe color
    }

    final normalized = code.toUpperCase().trim();

    // 1. Check strict known mappings
    if (_specificColors.containsKey(normalized)) {
      return _specificColors[normalized]!;
    }

    // 2. Check strict contains for common variations
    // Iterate keys to see if normalized code *contains* the key
    // e.g. "UU ITE 2024" should match "ITE"
    for (final key in _specificColors.keys) {
      if (normalized.contains(key)) {
        return _specificColors[key]!;
      }
    }

    // 3. Fallback: Hash-based deterministic color
    // Use hashCode to pick from palette. abs() is important.
    final index = normalized.hashCode.abs() % _fallbackPalette.length;
    return _fallbackPalette[index];
  }
}
