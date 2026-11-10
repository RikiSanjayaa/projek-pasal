import 'package:material_ui/material_ui.dart';

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

  /// Foreground shades retain the law hue while remaining readable on tints.
  static Color getColor(String? code, {required bool isDark}) {
    final shades = _foregroundShades[_getBaseColor(code).toARGB32()]!;
    return isDark ? shades.$2 : shades.$1;
  }

  static const _foregroundShades = <int, (Color, Color)>{
    0xFFDC2626: (Color(0xFFB91C1C), Color(0xFFFCA5A5)),
    0xFF2563EB: (Color(0xFF1D4ED8), Color(0xFF93C5FD)),
    0xFF059669: (Color(0xFF047857), Color(0xFF6EE7B7)),
    0xFFD97706: (Color(0xFF92400E), Color(0xFFFCD34D)),
    0xFF7C3AED: (Color(0xFF6D28D9), Color(0xFFC4B5FD)),
    0xFFDB2777: (Color(0xFFBE185D), Color(0xFFF9A8D4)),
    0xFF0891B2: (Color(0xFF0E7490), Color(0xFF67E8F9)),
    0xFF4F46E5: (Color(0xFF4338CA), Color(0xFFA5B4FC)),
    0xFFEA580C: (Color(0xFF9A3412), Color(0xFFFDBA74)),
    0xFF65A30D: (Color(0xFF3F6212), Color(0xFFBEF264)),
    0xFF0D9488: (Color(0xFF0F766E), Color(0xFF5EEAD4)),
    0xFF9333EA: (Color(0xFF7E22CE), Color(0xFFD8B4FE)),
    0xFFC026D3: (Color(0xFFA21CAF), Color(0xFFF0ABFC)),
    0xFFE11D48: (Color(0xFFBE123C), Color(0xFFFDA4AF)),
    0xFF4B5563: (Color(0xFF4B5563), Color(0xFFCBD5E1)),
    0xFFB45309: (Color(0xFF92400E), Color(0xFFFCD34D)),
    0xFF15803D: (Color(0xFF166534), Color(0xFF86EFAC)),
    0xFF4338CA: (Color(0xFF3730A3), Color(0xFFA5B4FC)),
    0xFF9E9E9E: (Color(0xFF4B5563), Color(0xFFCBD5E1)),
  };

  static Color _getBaseColor(String? code) {
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
