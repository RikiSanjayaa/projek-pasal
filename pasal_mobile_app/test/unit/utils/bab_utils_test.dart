import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/core/utils/bab_utils.dart';
import 'package:pasal_mobile_app/models/pasal_model.dart';

PasalModel _p(String uu, String nomor, String? bab, [String? judul]) => PasalModel(
  id: '$uu-$nomor',
  undangUndangId: uu,
  nomor: nomor,
  isi: 'isi',
  bab: bab,
  judul: judul,
);

void main() {
  group('BabUtils', () {
    test('titleOf returns the last part', () {
      expect(BabUtils.titleOf('Buku Kedua · Bab XXI · Tentang Hipotek'), 'Tentang Hipotek');
      expect(BabUtils.titleOf('Bab I'), 'Bab I');
    });

    test('groupsOf orders by UU then nomor, not alphabetically, and skips null bab', () {
      final groups = BabUtils.groupsOf(
        [
          _p('b', '1', 'Bab I · Zebra'),
          _p('a', '20', 'Bab II · Apel'),
          _p('a', '3', 'Bab I · Mangga'),
          _p('a', '4', 'Bab I · Mangga'),
          _p('a', '30', null),
        ],
        uuOrder: ['a', 'b'],
      );

      expect(groups.map((g) => '${g.undangUndangId}:${g.bab}'), [
        'a:Bab I · Mangga',
        'a:Bab II · Apel',
        'b:Bab I · Zebra',
      ]);
      expect(groups.first.count, 2);
    });

    test('juduls skip the ones equal to the bab title', () {
      final groups = BabUtils.groupsOf([
        _p('a', '1', 'Bab I · Pencurian', 'Pencurian'),
        _p('a', '2', 'Bab I · Pencurian', 'Pencurian Ringan'),
        _p('a', '3', 'Bab I · Pencurian', 'Pencurian Ringan'),
        _p('a', '4', 'Bab I · Pencurian'),
      ]);

      expect(groups.single.count, 4);
      expect(groups.single.juduls.map((j) => (j.judul, j.count)), [('Pencurian Ringan', 2)]);
    });

    test('matches checks UU, bab and optional judul', () {
      final p = _p('a', '1', 'Bab I · X', 'Judul');
      expect(BabUtils.matches(p, 'a', 'Bab I · X', null), isTrue);
      expect(BabUtils.matches(p, 'a', 'Bab I · X', 'Judul'), isTrue);
      expect(BabUtils.matches(p, 'a', 'Bab I · X', 'Lain'), isFalse);
      expect(BabUtils.matches(p, 'b', 'Bab I · X', null), isFalse);
    });
  });
}
