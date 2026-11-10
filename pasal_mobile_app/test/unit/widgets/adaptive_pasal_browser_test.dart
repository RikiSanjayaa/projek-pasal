import 'package:drift/drift.dart' show Value;
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
import 'package:pasal_mobile_app/ui/widgets/pasal_results_view.dart';
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
    expect(tester.getSize(find.byType(TextField)).width, 1365);
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
    tester.view.physicalSize = const Size(1365, 900);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AdaptivePasalBrowser(
            child: SizedBox.expand(
              child: PasalCard(pasal: article, contextList: [article]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PasalCard)).width, 1365);
    await tester.tap(find.byType(PasalCard));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PasalCard)).width, lessThan(500));
    await tester.tap(find.byTooltip('Kembali ke daftar'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PasalCard)).width, 1365);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reader keeps list order until an explicit chapter selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1568, 1000);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'has_shown_read_pasal_showcase': true,
      'has_shown_read_pasal_showcase_v2': true,
    });
    ShowcaseView.register();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    DataService.useDatabase(db);
    addTearDown(db.close);
    for (final law in ['A', 'B']) {
      await db
          .into(db.undangUndangTable)
          .insert(
            UndangUndangTableCompanion.insert(id: law, kode: law, nama: law),
          );
    }
    final articles = [
      for (final number in ['1', '2', '3'])
        PasalModel(
          id: 'A-$number',
          undangUndangId: 'A',
          nomor: number,
          isi: 'Isi ketentuan A $number',
          judul: 'Ketentuan A $number',
          bab: 'Bab I',
        ),
      PasalModel(
        id: 'B-9',
        undangUndangId: 'B',
        nomor: '9',
        isi: 'Isi ketentuan B 9',
        judul: 'Ketentuan B 9',
        bab: 'Bab I',
      ),
    ];
    for (final article in articles) {
      await db
          .into(db.pasalTable)
          .insert(
            PasalTableCompanion.insert(
              id: article.id,
              undangUndangId: article.undangUndangId,
              nomor: article.nomor,
              isi: article.isi,
              judul: Value(article.judul),
              bab: Value(article.bab),
            ),
          );
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ReadPasalScreen(
          pasal: articles[2],
          contextList: [articles[2], articles[3], articles[0]],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final next = find.byType(FilledButton);
    final previous = find.byType(OutlinedButton);
    Finder preview(String number) => find.textContaining(' - Pasal $number');
    expect(tester.widget<OutlinedButton>(previous).onPressed, isNull);
    expect(preview('9'), findsOneWidget);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(preview('9'), findsNothing);
    await tester.tap(next);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1568, 1000);
    await tester.pumpAndSettle();
    expect(preview('1'), findsOneWidget);
    expect(preview('3'), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
    await tester.tap(previous);
    await tester.pumpAndSettle();
    await tester.tap(previous);
    await tester.pumpAndSettle();
    // Choosing a chapter article switches to book order, even when later
    // articles are also present in the original cross-law opening list.
    await tester.tap(find.widgetWithText(ListTile, 'Pasal 2'));
    await tester.pumpAndSettle();
    expect(preview('3'), findsOneWidget);
    expect(preview('1'), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
    expect(preview('2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('grid cards share row height with unequal legal text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1365, 900);
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    DataService.useDatabase(db);
    addTearDown(db.close);
    await db
        .into(db.undangUndangTable)
        .insert(
          UndangUndangTableCompanion.insert(
            id: 'grid-law',
            kode: 'UU',
            nama: 'Hukum',
          ),
        );
    final articles = [
      PasalModel(
        id: 'short',
        undangUndangId: 'grid-law',
        nomor: '1',
        isi: 'Dicabut.',
      ),
      PasalModel(
        id: 'long',
        undangUndangId: 'grid-law',
        nomor: '2',
        judul: 'Ketentuan mengenai penyidikan, penuntutan, dan pelaksanaan pidana terhadap korporasi',
        isi: List.filled(20, 'Ketentuan pidana bagi setiap orang.').join(' '),
      ),
      PasalModel(
        id: 'medium',
        undangUndangId: 'grid-law',
        nomor: '3',
        isi: 'Ketentuan ini berlaku sejak tanggal diundangkan.',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PasalResultsView(items: articles, contextList: articles),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cards = find.byType(PasalCard);
    final height = tester.getSize(cards.at(1)).height;
    for (var i = 0; i < articles.length; i++) {
      expect(tester.getSize(cards.at(i)).height, closeTo(height, .01));
      expect(
        tester.getTopLeft(cards.at(i)).dy,
        tester.getTopLeft(cards.first).dy,
      );
    }
    expect(find.text(articles[1].judul!), findsOneWidget);
    tester.view.physicalSize = const Size(390, 900);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(cards.at(1)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(cards.first).dy),
    );
    expect(
      tester.getSize(cards.first).height,
      lessThan(tester.getSize(cards.at(1)).height),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
