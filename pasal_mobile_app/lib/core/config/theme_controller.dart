import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  static final ThemeController _instance = ThemeController._internal();

  factory ThemeController() => _instance;

  ThemeController._internal() : super(ThemeMode.system) {
    _loadTheme();
  }

  static const String _themeKey = 'theme_mode_v2'; // Changed key for migration

  /// Set theme to a specific mode
  void setTheme(ThemeMode mode) {
    value = mode;
    _saveTheme(mode);
  }

  /// Cycle through themes: System -> Light -> Dark -> System
  void cycle() {
    switch (value) {
      case ThemeMode.system:
        setTheme(ThemeMode.light);
        break;
      case ThemeMode.light:
        setTheme(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setTheme(ThemeMode.system);
        break;
    }
  }

  /// Legacy toggle (kept for compatibility)
  void toggle() {
    if (value == ThemeMode.light) {
      setTheme(ThemeMode.dark);
    } else {
      setTheme(ThemeMode.light);
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);

    if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      value = ThemeMode.values[themeIndex];
    } else {
      // Default to system theme
      value = ThemeMode.system;
    }
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  bool get isDark => value == ThemeMode.dark;
  bool get isLight => value == ThemeMode.light;
  bool get isSystem => value == ThemeMode.system;

  /// Get display name for current theme
  String get themeName {
    switch (value) {
      case ThemeMode.system:
        return 'Sistem';
      case ThemeMode.light:
        return 'Terang';
      case ThemeMode.dark:
        return 'Gelap';
    }
  }

  /// Get icon for current theme
  IconData get themeIcon {
    switch (value) {
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }
}

final themeController = ThemeController();
