import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/ui/widgets/law_content_formatter.dart';

void main() {
  group('splitPenjelasanBlocks', () {
    test('splits at Ayat/Huruf/Angka labels and keeps list lines in the body', () {
      final blocks = splitPenjelasanBlocks(
        'Ayat (1) Dalam ketentuan ini, perumusan dimaksudkan agar:\n'
        'a. diperoleh besaran yang jelas; dan\n'
        'b. lebih mudah menyesuaikan.\n'
        'Ayat (2) Cukup jelas.',
      );

      expect(blocks, hasLength(2));
      expect(blocks[0].label, 'Ayat (1)');
      expect(blocks[0].body, startsWith('Dalam ketentuan ini'));
      expect(blocks[0].body, contains('a. diperoleh besaran'));
      expect(blocks[0].body, contains('b. lebih mudah'));
      expect(blocks[1].label, 'Ayat (2)');
      expect(blocks[1].body, 'Cukup jelas.');
    });

    test('recognises Huruf and Angka labels', () {
      final blocks = splitPenjelasanBlocks(
        'Huruf a Cukup jelas.\nHuruf b Yang dimaksud adalah x.\nAngka 1 Cukup jelas.',
      );

      expect(blocks.map((b) => b.label), ['Huruf a', 'Huruf b', 'Angka 1']);
      expect(blocks[1].body, 'Yang dimaksud adalah x.');
    });

    test('text without labels stays one unlabeled block', () {
      final blocks = splitPenjelasanBlocks('Cukup jelas.');

      expect(blocks, hasLength(1));
      expect(blocks.single.label, isNull);
      expect(blocks.single.body, 'Cukup jelas.');
    });

    test('splits labels that follow a sentence on the same line', () {
      final blocks = splitPenjelasanBlocks(
        'Ayat (1) Cukup jelas. Ayat (2) Yang dimaksud adalah x.',
      );

      expect(blocks.map((b) => b.label), ['Ayat (1)', 'Ayat (2)']);
    });
  });

  group('normalizeLegalDisplayText', () {
    test('keeps a new capitalised sentence after a finished line as a paragraph', () {
      final text = normalizeLegalDisplayText(
        'b. lebih mudah menyesuaikan.\nPenetapan tingkatan dihitung sebagai berikut:',
      );

      expect(text.split('\n'), hasLength(2));
    });

    test('still joins hard-wrapped lines inside a sentence', () {
      final text = normalizeLegalDisplayText(
        'Setiap orang yang dengan sengaja\nmerampas nyawa orang lain',
      );

      expect(text, 'Setiap orang yang dengan sengaja merampas nyawa orang lain');
    });

    test('does not treat a parenthesised word like (lima) as a list marker', () {
      final text = normalizeLegalDisplayText(
        'Untuk kategori III adalah kelipatan 5 (lima) kali dari kategori II.',
      );

      expect(text.contains('\n'), isFalse);
    });
  });
}
