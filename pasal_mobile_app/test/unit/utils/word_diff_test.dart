import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/core/utils/word_diff.dart';

String _rebuild(List<DiffSegment> segments, {required bool newSide}) {
  final keep = newSide ? DiffOp.inserted : DiffOp.removed;
  return segments
      .where((s) => s.op == DiffOp.equal || s.op == keep)
      .map((s) => s.text)
      .join();
}

void main() {
  group('WordDiff', () {
    test('identical text yields a single equal segment', () {
      const text = 'Setiap orang dipidana penjara paling lama 5 tahun.';
      expect(WordDiff.compute(text, text), [
        const DiffSegment(DiffOp.equal, text),
      ]);
    });

    test('empty texts yield no segments', () {
      expect(WordDiff.compute('', ''), isEmpty);
    });

    test('single replaced word (Pasal 3 style)', () {
      const oldText =
          'Ketentuan pidana dalam peraturan perundang-undangan diterapkan bagi setiap orang yang melakukan tindak pidana di wilayah Indonesia.';
      const newText =
          'Ketentuan pidana dalam peraturan perundang-undangan diterapkan terhadap setiap orang yang melakukan tindak pidana di wilayah Indonesia.';
      final segments = WordDiff.compute(oldText, newText);

      expect(segments.map((s) => s.op).toList(), [
        DiffOp.equal,
        DiffOp.removed,
        DiffOp.inserted,
        DiffOp.equal,
      ]);
      expect(segments[0].text, endsWith('diterapkan '));
      expect(segments[1].text, 'bagi');
      expect(segments[2].text, 'terhadap');
      expect(segments[3].text, startsWith(' setiap orang'));
      expect(_rebuild(segments, newSide: false), oldText);
      expect(_rebuild(segments, newSide: true), newText);
    });

    test('inserted ayat is a pure insertion', () {
      const oldText = '(1) Setiap orang wajib taat.';
      const newText = '(1) Setiap orang wajib taat.\n(2) Pengecualian diatur lebih lanjut.';
      final segments = WordDiff.compute(oldText, newText);

      expect(segments.where((s) => s.op == DiffOp.removed), isEmpty);
      final inserted = segments.where((s) => s.op == DiffOp.inserted).toList();
      expect(inserted, hasLength(1));
      expect(inserted.single.text, '\n(2) Pengecualian diatur lebih lanjut.');
      expect(_rebuild(segments, newSide: true), newText);
    });

    test('full replacement becomes removed + inserted', () {
      final segments = WordDiff.compute('...', 'Dihapus.');
      expect(segments, [
        const DiffSegment(DiffOp.removed, '..'),
        const DiffSegment(DiffOp.inserted, 'Dihapus'),
        const DiffSegment(DiffOp.equal, '.'),
      ]);
      expect(_rebuild(segments, newSide: false), '...');
      expect(_rebuild(segments, newSide: true), 'Dihapus.');
    });

    test('whole different sentences give one removed and one inserted block', () {
      final segments = WordDiff.compute('alpha beta gamma', 'satu dua tiga');
      expect(segments, [
        const DiffSegment(DiffOp.removed, 'alpha beta gamma'),
        const DiffSegment(DiffOp.inserted, 'satu dua tiga'),
      ]);
    });

    test('spaces between two changes merge into one block', () {
      final segments = WordDiff.compute('a b c d', 'a x c y');
      expect(_rebuild(segments, newSide: false), 'a b c d');
      expect(_rebuild(segments, newSide: true), 'a x c y');
      // "b" -> "x", " c " tetap equal; "d" -> "y".
      expect(
        segments.where((s) => s.op == DiffOp.equal).map((s) => s.text),
        ['a ', ' c '],
      );
    });

    test('very large middle falls back to a single block replacement', () {
      final oldText = List.generate(3000, (i) => 'a$i').join(' ');
      final newText = List.generate(3000, (i) => 'b$i').join(' ');
      final sw = Stopwatch()..start();
      final segments = WordDiff.compute('x $oldText y', 'x $newText y');
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(segments.map((s) => s.op).toList(), [
        DiffOp.equal,
        DiffOp.removed,
        DiffOp.inserted,
        DiffOp.equal,
      ]);
      expect(_rebuild(segments, newSide: true), 'x $newText y');
    });

    test('long text with a few edits stays fast and exact', () {
      final words = List.generate(1500, (i) => 'kata$i');
      final edited = List.of(words)
        ..[200] = 'ganti'
        ..[900] = 'lain'
        ..removeAt(1200);
      final oldText = words.join(' ');
      final newText = edited.join(' ');
      final sw = Stopwatch()..start();
      final segments = WordDiff.compute(oldText, newText);
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(_rebuild(segments, newSide: false), oldText);
      expect(_rebuild(segments, newSide: true), newText);
      expect(segments.where((s) => s.op != DiffOp.equal), isNotEmpty);
    });
  });
}
