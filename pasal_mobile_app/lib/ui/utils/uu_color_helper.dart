import 'package:flutter/material.dart';

class UUColorHelper {
  // Singleton pattern for caching dynamic colors
  static final UUColorHelper _instance = UUColorHelper._internal();
  factory UUColorHelper() => _instance;
  UUColorHelper._internal();

  // Cache for dynamically assigned colors to ensure consistency across screens
  final Map<String, Color> _dynamicColorCache = {};
  int _nextColorIndex = 0;

  // 1. Preset Palette (The "Official" Colors)
  static final Map<String, Color> _specificColors = {
    'KUHP': const Color(0xFFDC2626), // Red
    'KUHAP': const Color(0xFF2563EB), // Blue
    'ITE': const Color(0xFF059669), // Emerald
    'KUHPER': const Color(0xFFD97706), // Amber
    'PERDATA': const Color(0xFFD97706), // Amber (Alias)
    'HAM': const Color(0xFF7C3AED), // Violet
    'KORUPSI': const Color(0xFFDB2777), // Pink
    'LALIN': const Color(0xFF0891B2), // Cyan
    'NARKOTIKA': const Color(0xFF4F46E5), // Indigo
  };

  // 2. Extra Palette for dynamic assignment (High quality colors)
  static const List<Color> _dynamicPalette = [
    Color(0xFFEA580C), // Orange
    Color(0xFF65A30D), // Lime
    Color(0xFF0D9488), // Teal
    Color(0xFF9333EA), // Purple
    Color(0xFFC026D3), // Fuchsia
    Color(0xFFE11D48), // Rose
    Color(0xFF4B5563), // Cool Grey
    Color(0xFFB45309), // Amber 700
    Color(0xFF15803D), // Green 700
    Color(0xFF0891B2), // Cyan 600
    Color(0xFF4338CA), // Indigo 700
  ];

  /// Get a consistent color for a given UU Code.
  static Color getColor(String? code) {
    if (code == null || code.trim().isEmpty) {
      return Colors.grey;
    }

    final normalized = code.toUpperCase().trim();

    // 1. Check strict/contains known mappings first
    // Specific checks for overlapping names (e.g. KUHPER vs KUHP)
    if (normalized.contains('KUHPER') || normalized.contains('PERDATA')) {
      return _specificColors['KUHPER']!;
    }
    if (normalized.contains('KUHAP')) {
      return _specificColors['KUHAP']!;
    }
    // Strict match for KUHP to avoid matching overlapping strings incorrectly if any
    if (normalized == 'KUHP' || normalized.startsWith('KUHP ')) {
      return _specificColors['KUHP']!;
    }

    // General contains check for others
    for (final key in _specificColors.keys) {
      if (normalized.contains(key)) {
        return _specificColors[key]!;
      }
    }

    // 2. Check Cache for previously assigned dynamic color
    if (_instance._dynamicColorCache.containsKey(normalized)) {
      return _instance._dynamicColorCache[normalized]!;
    }

    // 3. Assign new dynamic color (Round-robin or Hash fallbacks)
    Color newColor;
    if (_instance._nextColorIndex < _dynamicPalette.length) {
      // Use next available nice color
      newColor = _dynamicPalette[_instance._nextColorIndex];
      _instance._nextColorIndex =
          (_instance._nextColorIndex + 1) % _dynamicPalette.length;
    } else {
      // Fallback to deterministic hash if we somehow run out or wraparound logic varies
      final index = normalized.hashCode.abs() % _dynamicPalette.length;
      newColor = _dynamicPalette[index];
    }

    _instance._dynamicColorCache[normalized] = newColor;
    return newColor;
  }

  /// Get a consistent Icon for a given UU Code.
  static IconData getIcon(String? code) {
    if (code == null) return Icons.menu_book_rounded;
    final normalized = code.toUpperCase().trim();

    if (normalized == 'KUHP') return Icons.gavel_rounded;
    if (normalized.contains('KUHAP')) return Icons.policy_rounded;
    if (normalized.contains('ITE')) return Icons.computer_rounded;
    if (normalized.contains('KUHPER') || normalized.contains('PERDATA')) {
      return Icons.people_rounded;
    }
    if (normalized.contains('LALIN')) return Icons.directions_car_rounded;
    if (normalized.contains('KORUPSI')) return Icons.money_off_csred_rounded;
    if (normalized.contains('HAM')) return Icons.accessibility_new_rounded;
    if (normalized.contains('NARKOTIKA')) return Icons.medication_rounded;

    return Icons.menu_book_rounded;
  }
}
