import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/ui/screens/detail_uu_screen.dart';
import '../../helpers/widget_test_helper.dart';

void main() {
  setUp(() {
    setUpWidgetTests();
  });

  group('DetailUUScreen', () {
    final testUU = WidgetTestData.createUU(
      id: 'uu-test',
      kode: 'KUHP',
      nama: 'Kitab Undang-Undang Hukum Pidana',
      namaLengkap: 'Kitab Undang-Undang Hukum Pidana Indonesia',
      deskripsi: 'Undang-undang yang mengatur hukum pidana di Indonesia',
      tahun: 2023,
    );

    group('AppBar', () {
      testWidgets('displays UU kode in title', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();

        expect(find.text('KUHP'), findsWidgets);
      });

      testWidgets('has back button', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      });

      testWidgets('has menu button', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.menu), findsOneWidget);
      });
    });

    group('Header Section', () {
      testWidgets('displays UU header container', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Header container with UU info should be visible
        expect(find.text('KUHP'), findsWidgets);
      });

      testWidgets('displays UU nama', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Kitab Undang-Undang Hukum Pidana'), findsOneWidget);
      });

      testWidgets('displays namaLengkap if available', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Kitab Undang-Undang Hukum Pidana Indonesia'),
          findsOneWidget,
        );
      });

      testWidgets('displays tahun badge', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Tahun 2023'), findsOneWidget);
        expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      });

      testWidgets('displays pasal count', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.textContaining('Pasal'), findsWidgets);
        expect(find.byIcon(Icons.article_outlined), findsOneWidget);
      });
    });

    group('Description Section', () {
      testWidgets('displays deskripsi when available', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Tentang'), findsOneWidget);
        expect(
          find.text('Undang-undang yang mengatur hukum pidana di Indonesia'),
          findsOneWidget,
        );
      });

      testWidgets('hides deskripsi section when null', (tester) async {
        final uuNoDeskripsi = WidgetTestData.createUU(
          kode: 'TEST',
          nama: 'Test UU',
          deskripsi: null,
        );
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: uuNoDeskripsi)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Tentang'), findsNothing);
      });

      testWidgets('hides deskripsi section when empty', (tester) async {
        final uuEmptyDeskripsi = WidgetTestData.createUU(
          kode: 'TEST',
          nama: 'Test UU',
          deskripsi: '',
        );
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: uuEmptyDeskripsi)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Tentang'), findsNothing);
      });
    });

    group('Search Bar', () {
      testWidgets('renders search TextField', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('search hint includes UU nama', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Cari dalam Kitab Undang-Undang Hukum Pidana...'),
          findsOneWidget,
        );
      });

      testWidgets('shows clear button when text entered', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'pasal 1');
        await tester.pump();

        expect(find.byIcon(Icons.clear), findsOneWidget);
      });

      testWidgets('updates results label when searching', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Initially shows "Semua Pasal"
        expect(find.text('Semua Pasal'), findsOneWidget);

        // Enter search
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'test');
        await tester.pump();

        // Shows "Hasil Pencarian"
        expect(find.text('Hasil Pencarian'), findsOneWidget);
      });
    });

    group('Results Count', () {
      testWidgets('displays pasal count', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('0 pasal'), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('shows empty state when no pasal found', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
        expect(find.text('Tidak ditemukan'), findsOneWidget);
      });
    });

    group('Loading State', () {
      testWidgets('screen renders during data load', (tester) async {
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: testUU)),
        );
        await tester.pump();

        // Screen should render and show UU info even during loading
        expect(find.text('KUHP'), findsWidgets);
      });
    });

    group('Theme Support', () {
      testWidgets('renders correctly in light theme', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            DetailUUScreen(undangUndang: testUU),
            themeMode: ThemeMode.light,
          ),
        );
        await tester.pump();

        expect(find.byType(DetailUUScreen), findsOneWidget);
      });

      testWidgets('renders correctly in dark theme', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            DetailUUScreen(undangUndang: testUU),
            themeMode: ThemeMode.dark,
          ),
        );
        await tester.pump();

        expect(find.byType(DetailUUScreen), findsOneWidget);
      });
    });

    group('Navigation', () {
      testWidgets('back button pops navigation', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailUUScreen(undangUndang: testUU),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();

        expect(find.byType(DetailUUScreen), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.pumpAndSettle();

        expect(find.byType(DetailUUScreen), findsNothing);
      });
    });

    group('UU Color Theming', () {
      testWidgets('KUHP displays UU kode badge', (tester) async {
        final kuhp = WidgetTestData.createUU(kode: 'KUHP');
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: kuhp)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // UU kode badge should be visible
        expect(find.text('KUHP'), findsWidgets);
      });

      testWidgets('KUHAP displays UU kode badge', (tester) async {
        final kuhap = WidgetTestData.createUU(kode: 'KUHAP', nama: 'KUHAP');
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: kuhap)),
        );
        await tester.pump();

        expect(find.text('KUHAP'), findsWidgets);
      });

      testWidgets('ITE displays UU kode badge', (tester) async {
        final ite = WidgetTestData.createUU(kode: 'ITE', nama: 'ITE');
        await tester.pumpWidget(
          createTestApp(DetailUUScreen(undangUndang: ite)),
        );
        await tester.pump();

        expect(find.text('ITE'), findsWidgets);
      });
    });
  });
}
