import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/ui/utils/uu_color_helper.dart';

void main() {
  group('UUColorHelper', () {
    group('getColor', () {
      test('returns grey for null code', () {
        expect(UUColorHelper.getColor(null), Colors.grey);
      });

      test('returns grey for empty code', () {
        expect(UUColorHelper.getColor(''), Colors.grey);
        expect(UUColorHelper.getColor('   '), Colors.grey);
      });

      test('returns red for KUHP', () {
        final color = UUColorHelper.getColor('KUHP');
        expect(color, const Color(0xFFDC2626));
      });

      test('returns blue for KUHAP', () {
        final color = UUColorHelper.getColor('KUHAP');
        expect(color, const Color(0xFF2563EB));
      });

      test('returns emerald for ITE', () {
        final color = UUColorHelper.getColor('ITE');
        expect(color, const Color(0xFF059669));
      });

      test('returns amber for KUHPER/PERDATA', () {
        final colorKuhper = UUColorHelper.getColor('KUHPER');
        final colorPerdata = UUColorHelper.getColor('PERDATA');
        expect(colorKuhper, const Color(0xFFD97706));
        expect(colorPerdata, const Color(0xFFD97706));
      });

      test('handles case insensitivity', () {
        expect(UUColorHelper.getColor('kuhp'), const Color(0xFFDC2626));
        expect(UUColorHelper.getColor('Kuhp'), const Color(0xFFDC2626));
        expect(UUColorHelper.getColor('KUHP'), const Color(0xFFDC2626));
      });

      test('handles codes containing known keywords', () {
        // Should match KUHAP even with extra text
        final color = UUColorHelper.getColor('UU KUHAP');
        expect(color, const Color(0xFF2563EB));
      });

      test('KUHP strict match does not match KUHPER', () {
        // KUHPER should get amber, not red (KUHP)
        final color = UUColorHelper.getColor('KUHPER');
        expect(color, const Color(0xFFD97706)); // Amber, not red
      });

      test('returns consistent dynamic color for unknown codes', () {
        final color1 = UUColorHelper.getColor('UNKNOWN_LAW_1');
        final color2 = UUColorHelper.getColor('UNKNOWN_LAW_1');
        expect(color1, color2); // Same code should get same color
      });

      test('returns violet for HAM', () {
        expect(UUColorHelper.getColor('HAM'), const Color(0xFF7C3AED));
      });

      test('returns pink for KORUPSI', () {
        expect(UUColorHelper.getColor('KORUPSI'), const Color(0xFFDB2777));
      });

      test('returns cyan for LALIN', () {
        expect(UUColorHelper.getColor('LALIN'), const Color(0xFF0891B2));
      });

      test('returns indigo for NARKOTIKA', () {
        expect(UUColorHelper.getColor('NARKOTIKA'), const Color(0xFF4F46E5));
      });
    });

    group('getIcon', () {
      test('returns menu_book for null code', () {
        expect(UUColorHelper.getIcon(null), Icons.menu_book_rounded);
      });

      test('returns gavel for KUHP', () {
        expect(UUColorHelper.getIcon('KUHP'), Icons.gavel_rounded);
      });

      test('returns policy for KUHAP', () {
        expect(UUColorHelper.getIcon('KUHAP'), Icons.policy_rounded);
      });

      test('returns computer for ITE', () {
        expect(UUColorHelper.getIcon('ITE'), Icons.computer_rounded);
      });

      test('returns people for KUHPER/PERDATA', () {
        expect(UUColorHelper.getIcon('KUHPER'), Icons.people_rounded);
        expect(UUColorHelper.getIcon('PERDATA'), Icons.people_rounded);
      });

      test('returns car for LALIN', () {
        expect(UUColorHelper.getIcon('LALIN'), Icons.directions_car_rounded);
      });

      test('returns money_off for KORUPSI', () {
        expect(UUColorHelper.getIcon('KORUPSI'), Icons.money_off_csred_rounded);
      });

      test('returns accessibility for HAM', () {
        expect(UUColorHelper.getIcon('HAM'), Icons.accessibility_new_rounded);
      });

      test('returns medication for NARKOTIKA', () {
        expect(UUColorHelper.getIcon('NARKOTIKA'), Icons.medication_rounded);
      });

      test('returns default menu_book for unknown codes', () {
        expect(UUColorHelper.getIcon('UNKNOWN'), Icons.menu_book_rounded);
      });

      test('handles case insensitivity', () {
        expect(UUColorHelper.getIcon('kuhp'), Icons.gavel_rounded);
        expect(UUColorHelper.getIcon('Ite'), Icons.computer_rounded);
      });
    });
  });
}
