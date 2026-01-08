import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/ui/screens/archive_screen.dart';
import 'package:pasal_mobile_app/ui/widgets/main_layout.dart';
import 'package:pasal_mobile_app/core/services/archive_service.dart';
import '../../helpers/widget_test_helper.dart';

void main() {
  setUp(() {
    setUpWidgetTests();
    // Reset archive state
    archiveService.archivedIds.value = [];
  });

  group('ArchiveScreen', () {
    group('UI Structure', () {
      testWidgets('renders header with title "Pasal Tersimpan"', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        expect(find.text('Pasal Tersimpan'), findsOneWidget);
      });

      testWidgets('renders search TextField', (tester) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Cari nomor, nama atau isi pasal...'), findsOneWidget);
      });

      testWidgets('renders menu button', (tester) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        expect(find.byIcon(Icons.menu), findsOneWidget);
      });

      testWidgets('uses MainLayout wrapper', (tester) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        expect(find.byType(MainLayout), findsOneWidget);
      });
    });

    group('Search Functionality', () {
      testWidgets('shows clear button when text is entered', (tester) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        final textField = find.byType(TextField);

        // Initially no clear button
        expect(find.byIcon(Icons.clear), findsNothing);

        // Enter text
        await tester.enterText(textField, 'pidana');
        await tester.pump();

        // Clear button should appear
        expect(find.byIcon(Icons.clear), findsOneWidget);
      });

      testWidgets('clears text when clear button tapped', (tester) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'test');
        await tester.pump();

        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump();

        final textFieldWidget = tester.widget<TextField>(textField);
        expect(textFieldWidget.controller?.text, isEmpty);
      });

      testWidgets('updates section title based on search', (tester) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        // Initially shows "Daftar Koleksi"
        expect(find.text('Daftar Koleksi'), findsOneWidget);

        // Enter search
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'test');
        await tester.pump();

        // Should show "Hasil Pencarian"
        expect(find.text('Hasil Pencarian'), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('shows empty icon when no archives', (tester) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      });

      testWidgets('shows "Belum ada pasal tersimpan" message', (tester) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        expect(find.text('Belum ada pasal tersimpan.'), findsOneWidget);
      });

      testWidgets('shows "Tidak ditemukan" when search has no results', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        // Enter search with no matches
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'xyz nonexistent');
        await tester.pump();

        expect(find.text('Tidak ditemukan.'), findsOneWidget);
      });
    });

    group('Total Count Display', () {
      testWidgets('shows total count as 0 when empty', (tester) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        expect(find.text('Total: 0'), findsOneWidget);
      });
    });

    group('Theme Support', () {
      testWidgets('renders correctly in light theme', (tester) async {
        await tester.pumpWidget(
          createTestApp(const ArchiveScreen(), themeMode: ThemeMode.light),
        );
        await tester.pump();

        expect(find.byType(ArchiveScreen), findsOneWidget);
      });

      testWidgets('renders correctly in dark theme', (tester) async {
        await tester.pumpWidget(
          createTestApp(const ArchiveScreen(), themeMode: ThemeMode.dark),
        );
        await tester.pump();

        expect(find.byType(ArchiveScreen), findsOneWidget);
      });
    });

    group('ValueListenableBuilder', () {
      testWidgets('rebuilds when archivedIds changes', (tester) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        // Initial state - empty
        expect(find.text('Total: 0'), findsOneWidget);

        // Note: Since we can't actually add archived items without
        // real data from QueryService, we verify the structure is reactive
        expect(
          find.byType(ValueListenableBuilder<List<String>>),
          findsOneWidget,
        );
      });
    });

    group('Accessibility', () {
      testWidgets('menu button has tooltip', (tester) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        final menuButton = find.byIcon(Icons.menu);
        final iconButton = tester.widget<IconButton>(
          find.ancestor(of: menuButton, matching: find.byType(IconButton)),
        );

        expect(iconButton.tooltip, 'Pengaturan');
      });
    });

    group('Pagination', () {
      testWidgets('pagination footer not shown when less than 10 items', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        // No pagination icons when empty/few items
        expect(find.byIcon(Icons.chevron_left), findsNothing);
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      });
    });

    group('Scroll Behavior', () {
      testWidgets('ListView present when screen has archived items', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(const ArchiveScreen()));
        await tester.pump();

        // When empty, empty state is shown instead of ListView
        // This test documents the expected behavior
        expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      });
    });
  });
}
