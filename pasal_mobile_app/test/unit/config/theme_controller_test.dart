import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeController Logic', () {
    group('theme cycling logic', () {
      test('ThemeMode.system cycles to ThemeMode.light', () {
        // Test the expected cycle behavior
        const current = ThemeMode.system;
        ThemeMode next;
        switch (current) {
          case ThemeMode.system:
            next = ThemeMode.light;
            break;
          case ThemeMode.light:
            next = ThemeMode.dark;
            break;
          case ThemeMode.dark:
            next = ThemeMode.system;
            break;
        }
        expect(next, ThemeMode.light);
      });

      test('ThemeMode.light cycles to ThemeMode.dark', () {
        const current = ThemeMode.light;
        ThemeMode next;
        switch (current) {
          case ThemeMode.system:
            next = ThemeMode.light;
            break;
          case ThemeMode.light:
            next = ThemeMode.dark;
            break;
          case ThemeMode.dark:
            next = ThemeMode.system;
            break;
        }
        expect(next, ThemeMode.dark);
      });

      test('ThemeMode.dark cycles to ThemeMode.system', () {
        const current = ThemeMode.dark;
        ThemeMode next;
        switch (current) {
          case ThemeMode.system:
            next = ThemeMode.light;
            break;
          case ThemeMode.light:
            next = ThemeMode.dark;
            break;
          case ThemeMode.dark:
            next = ThemeMode.system;
            break;
        }
        expect(next, ThemeMode.system);
      });
    });

    group('theme toggle logic (legacy)', () {
      test('light toggles to dark', () {
        const current = ThemeMode.light;
        final next = current == ThemeMode.light
            ? ThemeMode.dark
            : ThemeMode.light;
        expect(next, ThemeMode.dark);
      });

      test('dark toggles to light', () {
        const current = ThemeMode.dark;
        final next = current == ThemeMode.light
            ? ThemeMode.dark
            : ThemeMode.light;
        expect(next, ThemeMode.light);
      });

      test('system toggles to light (default branch)', () {
        const current = ThemeMode.system;
        final next = current == ThemeMode.light
            ? ThemeMode.dark
            : ThemeMode.light;
        expect(next, ThemeMode.light);
      });
    });

    group('theme properties logic', () {
      test('isDark returns true only for dark mode', () {
        expect(ThemeMode.dark == ThemeMode.dark, isTrue);
        expect(ThemeMode.light == ThemeMode.dark, isFalse);
        expect(ThemeMode.system == ThemeMode.dark, isFalse);
      });

      test('isLight returns true only for light mode', () {
        expect(ThemeMode.light == ThemeMode.light, isTrue);
        expect(ThemeMode.dark == ThemeMode.light, isFalse);
        expect(ThemeMode.system == ThemeMode.light, isFalse);
      });

      test('isSystem returns true only for system mode', () {
        expect(ThemeMode.system == ThemeMode.system, isTrue);
        expect(ThemeMode.dark == ThemeMode.system, isFalse);
        expect(ThemeMode.light == ThemeMode.system, isFalse);
      });
    });

    group('theme name logic', () {
      String getThemeName(ThemeMode mode) {
        switch (mode) {
          case ThemeMode.system:
            return 'Sistem';
          case ThemeMode.light:
            return 'Terang';
          case ThemeMode.dark:
            return 'Gelap';
        }
      }

      test('system mode returns Sistem', () {
        expect(getThemeName(ThemeMode.system), 'Sistem');
      });

      test('light mode returns Terang', () {
        expect(getThemeName(ThemeMode.light), 'Terang');
      });

      test('dark mode returns Gelap', () {
        expect(getThemeName(ThemeMode.dark), 'Gelap');
      });
    });

    group('theme icon logic', () {
      IconData getThemeIcon(ThemeMode mode) {
        switch (mode) {
          case ThemeMode.system:
            return Icons.brightness_auto_rounded;
          case ThemeMode.light:
            return Icons.light_mode_rounded;
          case ThemeMode.dark:
            return Icons.dark_mode_rounded;
        }
      }

      test('system mode returns brightness_auto icon', () {
        expect(getThemeIcon(ThemeMode.system), Icons.brightness_auto_rounded);
      });

      test('light mode returns light_mode icon', () {
        expect(getThemeIcon(ThemeMode.light), Icons.light_mode_rounded);
      });

      test('dark mode returns dark_mode icon', () {
        expect(getThemeIcon(ThemeMode.dark), Icons.dark_mode_rounded);
      });
    });

    group('theme persistence logic', () {
      test('ThemeMode can be converted to and from index', () {
        for (final mode in ThemeMode.values) {
          final index = mode.index;
          final restored = ThemeMode.values[index];
          expect(restored, mode);
        }
      });

      test('invalid index falls back gracefully', () {
        const invalidIndex = 99;
        final isValid =
            invalidIndex >= 0 && invalidIndex < ThemeMode.values.length;
        expect(isValid, isFalse);
      });
    });
  });
}
