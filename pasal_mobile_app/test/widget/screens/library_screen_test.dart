import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/ui/screens/library_screen.dart';
import 'package:pasal_mobile_app/ui/widgets/main_layout.dart';
import '../../helpers/widget_test_helper.dart';

void main() {
  setUp(() {
    setUpWidgetTests();
  });

  group('LibraryScreen', () {
    group('UI Structure', () {
      testWidgets('renders header with title "Pustaka Hukum"', (tester) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Pustaka Hukum'), findsOneWidget);
      });

      testWidgets('renders subtitle description', (tester) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.text('Koleksi peraturan perundang-undangan Indonesia'),
          findsOneWidget,
        );
      });

      testWidgets('renders menu button', (tester) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byIcon(Icons.menu), findsOneWidget);
      });

      testWidgets('uses MainLayout wrapper', (tester) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(MainLayout), findsOneWidget);
      });
    });

    group('Stats Cards', () {
      testWidgets('renders Sumber stat card', (tester) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Sumber'), findsOneWidget);
        expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
      });

      testWidgets('renders Pasal stat card', (tester) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Pasal'), findsOneWidget);
        expect(find.byIcon(Icons.article_rounded), findsOneWidget);
      });

      testWidgets('shows count values in stat cards', (tester) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Shows 0 when no data loaded from database
        expect(find.text('0'), findsNWidgets(2));
      });
    });

    group('Section Header', () {
      testWidgets('renders "Semua Undang-Undang" section title', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Semua Undang-Undang'), findsOneWidget);
      });

      testWidgets('shows available count', (tester) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('0 tersedia'), findsOneWidget);
      });
    });

    group('Loading State', () {
      testWidgets('screen renders without crash during loading', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Screen should render without crashing
        expect(find.byType(LibraryScreen), findsOneWidget);
      });

      testWidgets('shows data after loading completes', (tester) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // After loading, stats should show 0 (no data from DB)
        expect(find.text('0'), findsWidgets);
      });
    });

    group('Empty State', () {
      testWidgets('shows empty state when no UU available', (tester) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // When data loads but is empty
        expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
        expect(find.text('Tidak ada hasil'), findsOneWidget);
        expect(find.text('Coba kata kunci lain'), findsOneWidget);
      });
    });

    group('Theme Support', () {
      testWidgets('renders correctly in light theme', (tester) async {
        await tester.pumpWidget(
          createTestApp(const LibraryScreen(), themeMode: ThemeMode.light),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(LibraryScreen), findsOneWidget);
      });

      testWidgets('renders correctly in dark theme', (tester) async {
        await tester.pumpWidget(
          createTestApp(const LibraryScreen(), themeMode: ThemeMode.dark),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(LibraryScreen), findsOneWidget);
      });
    });

    group('UU Card Structure', () {
      testWidgets('empty state visible when no UU data', (tester) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Empty state should be visible
        expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('menu button has tooltip', (tester) async {
        await tester.pumpWidget(createTestApp(const LibraryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final menuButton = find.byIcon(Icons.menu);
        final iconButton = tester.widget<IconButton>(
          find.ancestor(of: menuButton, matching: find.byType(IconButton)),
        );

        expect(iconButton.tooltip, 'Pengaturan');
      });
    });
  });
}
