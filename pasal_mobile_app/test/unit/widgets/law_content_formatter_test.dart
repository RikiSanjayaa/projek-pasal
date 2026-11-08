import 'package:flutter/material.dart';
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

  group('LawContentFormatter.diff', () {
    Future<List<TextSpan>> pumpDiff(WidgetTester tester, String a, String b) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LawContentFormatter.diff(segments: diffLegalTexts(a, b)),
            ),
          ),
        ),
      );
      final spans = <TextSpan>[];
      for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
        rt.text.visitChildren((s) {
          if (s is TextSpan && s.text != null) spans.add(s);
          return true;
        });
      }
      return spans;
    }

    testWidgets('marks replaced word and keeps list structure', (tester) async {
      final spans = await pumpDiff(
        tester,
        '(1) Berlaku bagi setiap orang.\n(2) Ayat dua.',
        '(1) Berlaku terhadap setiap orang.\n(2) Ayat dua.',
      );
      final removed = spans.where(
        (s) => s.style?.decoration == TextDecoration.lineThrough,
      );
      final inserted = spans.where(
        (s) => s.style?.decoration == TextDecoration.underline,
      );
      expect(removed.map((s) => s.text), ['bagi']);
      expect(inserted.map((s) => s.text), ['terhadap']);
      expect(find.text('(1)'), findsOneWidget);
      expect(find.text('(2)'), findsOneWidget);
    });

    testWidgets('inserted ayat is rendered as an underlined list item', (
      tester,
    ) async {
      final spans = await pumpDiff(
        tester,
        '(1) Satu.',
        '(1) Satu.\n(2) Dua baru.',
      );
      final inserted = spans.where(
        (s) => s.style?.decoration == TextDecoration.underline,
      );
      expect(inserted.map((s) => s.text).join(), contains('Dua baru.'));
      expect(find.text('(2)'), findsOneWidget);
    });
  });

  group('normalizeLegalDisplayText: rujukan di tengah kalimat', () {
    const ayat3 =
        '(3) Dalam hal ketentuan sebagaimana dimaksud pada ayat (2) diterapkan '
        'terhadap tersangka atau terdakwa yang berada dalam tahanan, tersangka '
        'atau terdakwa dibebaskan oleh Pejabat yang berwenang sesuai dengan '
        'tingkat pemeriksaan.';
    const ayat6 =
        '(6) Pembebasan sebagaimana dimaksud pada ayat (3) dan ayat (5) tidak '
        'menimbulkan hak bagi tersangka, terdakwa, atau terpidana menuntut '
        'ganti rugi.';

    test('KUHP Pasal 3 ayat (3) tetap satu butir', () {
      final text =
          '(1) Dalam hal terdapat perubahan. (2) Dalam hal perbuatan terjadi. $ayat3 (4) Dalam hal setelah putusan.';
      final lines = normalizeLegalDisplayText(text).split('\n');
      expect(lines, hasLength(4));
      expect(lines[2], ayat3);
    });

    test('ayat (3) dan ayat (5) tidak dipecah', () {
      final lines = normalizeLegalDisplayText('$ayat3 $ayat6').split('\n');
      expect(lines, [ayat3, ayat6]);
    });

    test('Pasal 5 ayat (3), huruf a, dan "ayat (1) dan (2)" tidak dipecah', () {
      for (final t in [
        '(1) Sebagaimana dimaksud dalam Pasal 5 ayat (3) berlaku.',
        '(1) Sebagaimana dimaksud dalam ayat (1) huruf a berlaku.',
        '(1) Berlaku bagi ayat (1) dan (2) sekaligus.',
        '(1) Sebagaimana dimaksud pada ayat (1) sampai dengan (3) berlaku.',
      ]) {
        expect(normalizeLegalDisplayText(t), t);
      }
    });

    test('rujukan di awal baris setelah kata ayat tetap menyambung', () {
      final out = normalizeLegalDisplayText(
        '(3) Dalam hal ketentuan sebagaimana dimaksud pada ayat\n(2) diterapkan terhadap tersangka.',
      );
      expect(out, '(3) Dalam hal ketentuan sebagaimana dimaksud pada ayat (2) diterapkan terhadap tersangka.');
    });

    test('butir daftar sungguhan tetap dipecah', () {
      final out = normalizeLegalDisplayText(
        '(1) Satu butir. (2) Dua butir:\na. huruf pertama; b. huruf kedua.',
      );
      expect(out.split('\n'), [
        '(1) Satu butir.',
        '(2) Dua butir:',
        'a. huruf pertama;',
        'b. huruf kedua.',
      ]);
    });

    testWidgets('rujukan ayat (2) tidak menjadi butir daftar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LawContentFormatter(
                content:
                    '(1) Satu. (2) Dua. $ayat3 (4) Empat.',
              ),
            ),
          ),
        ),
      );
      expect(find.text('(2)'), findsOneWidget);
      expect(find.text('(3)'), findsOneWidget);
      expect(find.text('(4)'), findsOneWidget);
    });
  });
}
