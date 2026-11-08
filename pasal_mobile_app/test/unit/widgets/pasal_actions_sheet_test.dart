import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pasal_mobile_app/ui/widgets/pasal_actions_sheet.dart';

void main() {
  testWidgets('every action stays reachable on a short landscape screen', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    String? tapped;
    final labels = ['Simpan pasal', 'Salin pasal', 'Cetak atau unduh PDF', 'Buka naskah resmi', 'Riwayat perubahan'];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPasalActionsSheet(
                context,
                title: 'KUHP Pasal 476',
                actions: [
                  for (final label in labels)
                    PasalAction(
                      icon: Icons.circle,
                      label: label,
                      description: 'Keterangan',
                      onTap: () => tapped = label,
                    ),
                ],
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Riwayat perubahan'), 50, scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Riwayat perubahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riwayat perubahan'));
    await tester.pumpAndSettle();
    expect(tapped, 'Riwayat perubahan');
  });
}
