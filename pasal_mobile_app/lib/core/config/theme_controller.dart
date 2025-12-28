import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  static final ThemeController _instance = ThemeController._internal();
  
  factory ThemeController() => _instance;
  
  ThemeController._internal() : super(ThemeMode.light) {
    _loadTheme(); 
  }

  static const String _themeKey = 'theme_mode';

  void toggle() async {
    value = value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme(value);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey) ?? false; 
    value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, mode == ThemeMode.dark);
  }
  
  bool get isDark => value == ThemeMode.dark;
}

final themeController = ThemeController();