import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pasal_mobile_app/core/config/app_theme.dart';
import 'package:pasal_mobile_app/core/database/app_database.dart';
import 'package:pasal_mobile_app/core/services/data_service.dart';
import 'package:pasal_mobile_app/models/pasal_model.dart';
import 'package:pasal_mobile_app/ui/widgets/adaptive_pasal_browser.dart';
import 'package:pasal_mobile_app/ui/widgets/explore_pasal_results.dart';
import 'package:pasal_mobile_app/ui/widgets/pasal_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

void main() {
  testWidgets(
    'automatic paging keeps the opened article and restores browsing',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1365, 1000);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'has_shown_read_pasal_showcase': true,
        'has_shown_read_pasal_showcase_v2': true,
      });
      ShowcaseView.register();
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      DataService.useDatabase(database);
      addTearDown(database.close);
      await database
          .into(database.undangUndangTable)
          .insert(
            UndangUndangTableCompanion.insert(
              id: 'law',
              kode: 'UU',
              nama: 'Hukum',
            ),
          );
      final articles = [
        for (var number = 1; number <= 45; number++)
          PasalModel(
            id: '$number',
            undangUndangId: 'law',
            nomor: '$number',
            isi: 'Ketentuan nomor $number.',
          ),
      ];
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Widget application() => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AdaptivePasalBrowser(
            child: ExplorePasalResults(
              items: articles,
              controller: controller,
              searchQuery: '',
            ),
          ),
        ),
      );
      Future<void> chooseSize(String label) async {
        await tester.scrollUntilVisible(
          find.byType(DropdownButton<int>),
          350,
          scrollable: find
              .descendant(
                of: find.byType(ExplorePasalResults),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButton<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      Future<void> openArticle(String number) async {
        await tester.scrollUntilVisible(
          find.text('Pasal $number'),
          350,
          scrollable: find
              .descendant(
                of: find.byType(ExplorePasalResults),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.text('Pasal $number'));
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(application());
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      await openArticle('25');
      expect(find.text('3 / 5'), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali ke daftar'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);

      await chooseSize('20');
      expect(find.text('1 / 3'), findsOneWidget);
      await openArticle('15');
      expect(find.text('1 / 3', skipOffstage: false), findsOneWidget);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.text('1 / 3', skipOffstage: false), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali ke daftar'));
      await tester.pumpAndSettle();

      // A fresh mount uses the stored manual choice even on a small screen.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(application());
      await tester.pumpAndSettle();
      expect(find.text('1 / 3', skipOffstage: false), findsOneWidget);
      await chooseSize('Otomatis (10)');
      expect(find.text('1 / 5', skipOffstage: false), findsOneWidget);
      tester.view.physicalSize = const Size(1365, 1000);
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('automatic resize keeps the leading visible article', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1365, 700);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final articles = [
      for (var number = 1; number <= 65; number++)
        PasalModel(
          id: '$number',
          undangUndangId: 'law',
          nomor: '$number',
          isi: 'Ketentuan nomor $number. ' * (number % 4 + 1),
        ),
    ];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 250),
              Expanded(
                child: AdaptivePasalBrowser(
                  child: ExplorePasalResults(
                    items: articles,
                    controller: controller,
                    searchQuery: '',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Pasal 25'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ExplorePasalResults),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byType(ExplorePasalResults));
    final leading =
        tester.elementList(find.byType(PasalCard)).firstWhere((element) {
              final rect = tester.getRect(find.byWidget(element.widget));
              return rect.bottom > viewport.top && rect.top < viewport.bottom;
            }).widget
            as PasalCard;
    final anchor = leading.pasal.nomor;
    expect(int.parse(anchor), greaterThan(10));
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.text('Pasal $anchor').hitTestable(), findsOneWidget);
    tester.view.physicalSize = const Size(1365, 700);
    await tester.pumpAndSettle();
    expect(find.text('Pasal $anchor').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
