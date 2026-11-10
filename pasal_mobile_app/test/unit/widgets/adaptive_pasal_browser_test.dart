import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pasal_mobile_app/core/config/app_theme.dart';
import 'package:pasal_mobile_app/core/database/app_database.dart';
import 'package:pasal_mobile_app/core/services/data_service.dart';
import 'package:pasal_mobile_app/models/pasal_model.dart';
import 'package:pasal_mobile_app/ui/screens/read_pasal_screen.dart';
import 'package:pasal_mobile_app/ui/widgets/adaptive_pasal_browser.dart';
import 'package:pasal_mobile_app/ui/widgets/pasal_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

void main() {
  testWidgets('query and reading position survive both layout breakpoints', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1365, 900);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'has_shown_read_pasal_showcase': true,
      'has_shown_read_pasal_showcase_v2': true,
    });
    ShowcaseView.register();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    DataService.useDatabase(db);
    addTearDown(db.close);
    final article = PasalModel(
      id: 'article-1',
      undangUndangId: 'law-1',
      nomor: '1',
      isi: List.generate(80, (i) => 'Ketentuan hukum nomor $i.').join('\n\n'),
    );
    await db
        .into(db.undangUndangTable)
        .insert(
          UndangUndangTableCompanion.insert(
            id: 'law-1',
            kode: 'UU',
            nama: 'Hukum',
          ),
        );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AdaptivePasalBrowser(
            child: Column(
              children: [
                const TextField(decoration: InputDecoration(labelText: 'Cari')),
                Expanded(
                  child: ListView(
                    children: [
                      PasalCard(pasal: article, contextList: [article]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ketentuan');
    await tester.tap(find.byType(PasalCard));
    await tester.pumpAndSettle();
    final reader = find.byType(ReadPasalScreen);
    final readerScroll = find
        .descendant(of: reader, matching: find.byType(SingleChildScrollView))
        .first;
    final controller = tester
        .widget<SingleChildScrollView>(readerScroll)
        .controller!;
    controller.jumpTo(400);
    await tester.pumpAndSettle();

    for (final width in [390.0, 800.0, 1365.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(find.byType(ReadPasalScreen), findsOneWidget);
      expect(controller.offset, 400);
      expect(find.text('Baca Pasal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    tester.view.physicalSize = const Size(390, 900);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kembali ke daftar'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadPasalScreen), findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'ketentuan',
    );
    expect(find.byType(PasalCard), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
