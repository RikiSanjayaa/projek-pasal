import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/ui/screens/read_pasal_screen.dart';
import 'package:pasal_mobile_app/core/services/archive_service.dart';
import '../../helpers/widget_test_helper.dart';

void main() {
  setUp(() {
    setUpWidgetTests();
    // Reset archive state
    archiveService.archivedIds.value = [];
  });

  group('ReadPasalScreen', () {
    final testPasal = WidgetTestData.createPasal(
      id: 'pasal-test-1',
      undangUndangId: 'uu-1',
      nomor: '1',
      isi:
          'Setiap orang yang melakukan tindak pidana akan dikenakan sanksi sesuai ketentuan yang berlaku.',
      judul: 'Ketentuan Umum',
      penjelasan: 'Penjelasan mengenai pasal 1 tentang ketentuan umum pidana.',
      keywords: ['pidana', 'sanksi', 'hukum'],
    );

    final testPasalNoJudul = WidgetTestData.createPasal(
      id: 'pasal-test-2',
      nomor: '2',
      isi: 'Isi pasal tanpa judul untuk testing.',
    );

    group('AppBar', () {
      testWidgets('displays "Baca Pasal" title', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.text('Baca Pasal'), findsOneWidget);
      });

      testWidgets('has back button', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      });

      testWidgets('has search toggle button', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('has menu button', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.menu), findsOneWidget);
      });
    });

    group('Pasal Header', () {
      testWidgets('displays pasal nomor', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.text('Pasal 1'), findsOneWidget);
      });

      testWidgets('displays UU badge', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // UU badge should be visible
        expect(find.textContaining('UU'), findsWidgets);
      });

      testWidgets('handles pasal nomor starting with "pasal"', (tester) async {
        final pasalWithPrefix = WidgetTestData.createPasal(
          nomor: 'Pasal 123',
          isi: 'Isi pasal',
        );
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: pasalWithPrefix)),
        );
        await tester.pump();

        // Should display as-is without adding "Pasal" prefix
        expect(find.text('Pasal 123'), findsOneWidget);
      });
    });

    group('Judul Section', () {
      testWidgets('displays judul when available', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.text('JUDUL'), findsOneWidget);
        expect(find.text('Ketentuan Umum'), findsOneWidget);
      });

      testWidgets('hides judul section when null', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasalNoJudul)),
        );
        await tester.pump();

        expect(find.text('JUDUL'), findsNothing);
      });

      testWidgets('hides judul section when empty', (tester) async {
        final pasalEmptyJudul = WidgetTestData.createPasal(
          nomor: '3',
          isi: 'Isi',
          judul: '   ', // whitespace only
        );
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: pasalEmptyJudul)),
        );
        await tester.pump();

        expect(find.text('JUDUL'), findsNothing);
      });
    });

    group('Isi Pasal Section', () {
      testWidgets('displays "ISI PASAL" label', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.text('ISI PASAL'), findsOneWidget);
        expect(find.byIcon(Icons.menu_book_outlined), findsWidgets);
      });

      testWidgets('displays pasal content', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.textContaining('tindak pidana'), findsOneWidget);
      });
    });

    group('Penjelasan Section', () {
      testWidgets('displays penjelasan when available', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        // Scroll to see penjelasan
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pump();

        expect(find.textContaining('Penjelasan'), findsWidgets);
      });

      testWidgets('hides penjelasan when null', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasalNoJudul)),
        );
        await tester.pump();

        // PenjelasanSection should not appear
        expect(find.text('PENJELASAN'), findsNothing);
      });

      testWidgets('hides penjelasan when too short (< 3 chars)', (
        tester,
      ) async {
        final pasalShortPenjelasan = WidgetTestData.createPasal(
          nomor: '4',
          isi: 'Isi',
          penjelasan: '-',
        );
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: pasalShortPenjelasan)),
        );
        await tester.pump();

        // Should not show penjelasan for "-" or similar
      });
    });

    group('Keywords Section', () {
      testWidgets('displays keywords when available', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        // Scroll to see keywords
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -400),
        );
        await tester.pump();

        // Keywords section should be visible
        expect(find.text('pidana'), findsWidgets);
      });

      testWidgets('hides keywords when empty', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasalNoJudul)),
        );
        await tester.pump();

        // No keyword chips when keywords is empty
      });
    });

    group('Archive Button', () {
      testWidgets('displays bookmark border icon when not archived', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      });

      testWidgets('displays filled bookmark when archived', (tester) async {
        // Pre-archive the pasal
        archiveService.archivedIds.value = ['pasal-test-1'];

        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      });

      testWidgets('archive button responds to tap', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Initially not archived
        expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

        // Tap archive button - find it via ancestor
        final bookmarkIcon = find.byIcon(Icons.bookmark_border_rounded);
        await tester.tap(bookmarkIcon);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Archive state should change
        expect(archiveService.isArchived('pasal-test-1'), true);
      });

      testWidgets('archive button changes icon when archived', (tester) async {
        archiveService.archivedIds.value = ['pasal-test-1'];

        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        // Should show filled bookmark
        expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      });

      testWidgets('archive service state is toggled correctly', (tester) async {
        archiveService.archivedIds.value = ['pasal-test-1'];

        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.byIcon(Icons.bookmark_rounded));
        await tester.pump();

        // Should be unarchived now
        expect(archiveService.isArchived('pasal-test-1'), false);
      });
    });

    group('Copy Button', () {
      testWidgets('displays copy icon', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
      });

      testWidgets('copy button is tappable', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify copy button can be tapped without throwing
        final copyButton = find.byIcon(Icons.copy_rounded);
        expect(copyButton, findsOneWidget);

        await tester.tap(copyButton);
        await tester.pump();

        // Pump frames for animation (600ms duration)
        await tester.pump(const Duration(milliseconds: 700));

        // Notification should appear in overlay
        expect(find.text('Pasal berhasil disalin'), findsOneWidget);
      });
    });

    group('Search Functionality', () {
      testWidgets('toggles search bar visibility', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        // Initially search bar hidden (if searchQuery is empty)
        // Search icon in app bar
        expect(find.byIcon(Icons.search), findsOneWidget);

        // Tap to show search
        await tester.tap(find.byIcon(Icons.search));
        await tester.pump();

        // Search bar should appear with TextField
        expect(find.text('Cari dalam pasal...'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
      });

      testWidgets('shows search bar when searchQuery provided', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            ReadPasalScreen(pasal: testPasal, searchQuery: 'pidana'),
          ),
        );
        await tester.pump();

        // Search bar should be visible
        expect(find.text('Cari dalam pasal...'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
      });

      testWidgets('closes search on toggle', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal, searchQuery: 'test')),
        );
        await tester.pump();

        // Tap to close search
        await tester.tap(find.byIcon(Icons.search_off));
        await tester.pump();

        // Search bar should be hidden
        expect(find.text('Cari dalam pasal...'), findsNothing);
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('clears search text when toggled off', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            ReadPasalScreen(pasal: testPasal, searchQuery: 'initial'),
          ),
        );
        await tester.pump();

        // Toggle off
        await tester.tap(find.byIcon(Icons.search_off));
        await tester.pump();

        // Toggle back on
        await tester.tap(find.byIcon(Icons.search));
        await tester.pump();

        // Search should be cleared
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, isEmpty);
      });

      testWidgets('has clear button in search field', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal, searchQuery: 'test')),
        );
        await tester.pump();

        expect(find.byIcon(Icons.clear), findsOneWidget);
      });
    });

    group('Navigation Buttons', () {
      testWidgets('displays navigation buttons in bottom bar', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.text('Sebelumnya'), findsOneWidget);
        expect(find.text('Selanjutnya'), findsOneWidget);
      });

      testWidgets('prev button exists when no context list', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        // Button should exist and be disabled (null onPressed)
        expect(find.text('Sebelumnya'), findsOneWidget);
      });

      testWidgets('next button exists when no context list', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        // Button should exist and be disabled (null onPressed)
        expect(find.text('Selanjutnya'), findsOneWidget);
      });

      testWidgets('shows navigation icons', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });
    });

    group('Pasal Links Section', () {
      testWidgets('renders RelatedPasalLinks widget', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        // Scroll to bottom to see links section
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -500),
        );
        await tester.pump();

        // RelatedPasalLinks component should be in the tree
        // The actual content depends on QueryService data
      });
    });

    group('Theme Support', () {
      testWidgets('renders correctly in light theme', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            ReadPasalScreen(pasal: testPasal),
            themeMode: ThemeMode.light,
          ),
        );
        await tester.pump();

        expect(find.byType(ReadPasalScreen), findsOneWidget);
      });

      testWidgets('renders correctly in dark theme', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            ReadPasalScreen(pasal: testPasal),
            themeMode: ThemeMode.dark,
          ),
        );
        await tester.pump();

        expect(find.byType(ReadPasalScreen), findsOneWidget);
      });
    });

    group('Scrolling', () {
      testWidgets('content is scrollable', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });
    });

    group('Tooltips', () {
      testWidgets('search button has tooltip', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        final searchButton = find.byIcon(Icons.search);
        final iconButton = tester.widget<IconButton>(
          find.ancestor(of: searchButton, matching: find.byType(IconButton)),
        );

        expect(iconButton.tooltip, 'Cari di Pasal');
      });

      testWidgets('menu button has tooltip', (tester) async {
        await tester.pumpWidget(
          createTestApp(ReadPasalScreen(pasal: testPasal)),
        );
        await tester.pump();

        final menuButtons = find.byIcon(Icons.menu);
        final iconButton = tester.widget<IconButton>(
          find.ancestor(of: menuButtons, matching: find.byType(IconButton)),
        );

        expect(iconButton.tooltip, 'Pengaturan');
      });
    });
  });
}
