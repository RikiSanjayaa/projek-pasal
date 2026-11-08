import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pasal_mobile_app/models/pasal_versi_model.dart';
import 'package:pasal_mobile_app/ui/widgets/riwayat_pasal.dart';

PasalVersiModel _v({
  String status = 'diubah',
  String? sumber,
  String? diundangkan,
  String? berlakuSejak,
}) {
  return PasalVersiModel(
    id: 'v1',
    pasalId: 'p1',
    urutan: 2,
    status: status,
    sumber: sumber,
    diundangkan: diundangkan,
    berlakuSejak: berlakuSejak,
    isi: 'Isi',
  );
}

Future<void> _pump(WidgetTester tester, PasalVersiModel latest) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PasalRiwayatChip(versi: [latest])),
    ),
  );
}

void main() {
  group('PasalVersiModel.year', () {
    test('prefers diundangkan, then berlaku_sejak, then sumber', () {
      expect(
        _v(diundangkan: '2006-08-01', berlakuSejak: '2007-01-01', sumber: 'Stb. 1872 No. 11').year,
        2006,
      );
      expect(_v(berlakuSejak: '1999-05-05', sumber: 'Stb. 1872 No. 11').year, 1999);
      expect(_v(sumber: 'Stb. 1872 No. 11').year, 1872);
    });

    test('is null without date or year in sumber', () {
      expect(_v().year, isNull);
      expect(_v(sumber: 'Staatsblad').year, isNull);
      expect(_v(sumber: 'UU 23/2006').year, 2006);
    });

    test('isPraKemerdekaan only for years before 1945', () {
      expect(_v(sumber: 'Stb. 1872 No. 11').isPraKemerdekaan, isTrue);
      expect(_v(sumber: 'Stb. 1945 No. 1').isPraKemerdekaan, isFalse);
      expect(_v().isPraKemerdekaan, isFalse);
    });
  });

  group('PasalRiwayatChip', () {
    testWidgets('hidden for Staatsblad change before 1945', (tester) async {
      await _pump(tester, _v(sumber: 'Stb. 1872 No. 11'));
      expect(find.byIcon(Icons.history_rounded), findsNothing);
    });

    testWidgets('shown for dihapus even before 1945', (tester) async {
      await _pump(tester, _v(status: 'dihapus', sumber: 'Stb. 1872 No. 11'));
      expect(find.text('Dihapus Stb. 1872 No. 11'), findsOneWidget);
    });

    testWidgets('shown for post-independence change with date', (tester) async {
      await _pump(
        tester,
        _v(sumber: 'UU 23/2006', diundangkan: '2006-12-29'),
      );
      expect(find.text('Diubah UU 23/2006'), findsOneWidget);
    });

    testWidgets('shown when no year can be read', (tester) async {
      await _pump(tester, _v(sumber: 'Staatsblad'));
      expect(find.text('Diubah Staatsblad'), findsOneWidget);
    });
  });
}
