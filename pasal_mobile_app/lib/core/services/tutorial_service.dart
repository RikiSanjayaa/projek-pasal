import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const List<String> _allTutorialKeys = [
    'has_shown_home_showcase',
    'has_shown_settings_showcase',
    'has_shown_read_pasal_showcase',
  ];

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (var key in _allTutorialKeys) {
      await prefs.remove(key);
    }
  }

  static Future<void> skipAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (var key in _allTutorialKeys) {
      await prefs.setBool(key, true);
    }
  }
}
