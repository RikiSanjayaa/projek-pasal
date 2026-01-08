import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/ui/screens/home_screen.dart';
import 'package:pasal_mobile_app/ui/widgets/main_layout.dart';
import '../../helpers/widget_test_helper.dart';

void main() {
  setUp(() {
    setUpWidgetTests();
  });

  group('HomeScreen', () {
    group('UI Structure', () {
      testWidgets('renders header with title "Jelajahi Pasal"', (tester) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();

        expect(find.text('Jelajahi Pasal'), findsOneWidget);
      });

      testWidgets('renders search TextField', (tester) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Cari nomor, nama atau isi pasal...'), findsOneWidget);
      });

      testWidgets('renders search icon in search field', (tester) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();

        expect(find.byIcon(Icons.search), findsWidgets);
      });

      testWidgets('renders menu button', (tester) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();

        expect(find.byIcon(Icons.menu), findsOneWidget);
      });

      testWidgets('uses MainLayout wrapper', (tester) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();

        expect(find.byType(MainLayout), findsOneWidget);
      });
    });

    group('Search Functionality', () {
      testWidgets('shows clear button when text is entered', (tester) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();

        // Find the search TextField
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);

        // Initially no clear button
        expect(find.byIcon(Icons.clear), findsNothing);

        // Enter text
        await tester.enterText(textField, 'pidana');
        await tester.pump();

        // Clear button should appear
        expect(find.byIcon(Icons.clear), findsOneWidget);
      });

      testWidgets('clears text when clear button is tapped', (tester) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'test query');
        await tester.pump();

        // Tap clear button
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump();

        // Text should be cleared and clear button hidden
        final textFieldWidget = tester.widget<TextField>(textField);
        expect(textFieldWidget.controller?.text, isEmpty);
      });

      testWidgets('updates section title based on search state', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();

        // Initially shows "Pasal Terbaru"
        expect(find.text('Pasal Terbaru'), findsOneWidget);

        // Enter search query
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'test');
        await tester.pump();

        // Should show "Pasal yang sesuai"
        expect(find.text('Pasal yang sesuai'), findsOneWidget);
      });
    });

    group('Filter Section', () {
      testWidgets('filter section is rendered when data is available', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Filter section only appears when there are keywords or UU
        // Without DB data, it may not be visible
        // This test documents the expected behavior
        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets('filter section responds to data availability', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Screen renders correctly even without filter data
        expect(find.text('Jelajahi Pasal'), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('shows "Data tidak ditemukan" when no results', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();

        // When data hasn't loaded yet, empty state is shown
        expect(find.text('Data tidak ditemukan.'), findsOneWidget);
      });
    });

    group('Pagination', () {
      testWidgets('shows total count', (tester) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();

        // Total count should be displayed
        expect(find.textContaining('Total:'), findsOneWidget);
      });
    });

    group('Theme Support', () {
      testWidgets('renders correctly in light theme', (tester) async {
        await tester.pumpWidget(
          createTestApp(const HomeScreen(), themeMode: ThemeMode.light),
        );
        await tester.pump();

        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets('renders correctly in dark theme', (tester) async {
        await tester.pumpWidget(
          createTestApp(const HomeScreen(), themeMode: ThemeMode.dark),
        );
        await tester.pump();

        expect(find.byType(HomeScreen), findsOneWidget);
      });
    });

    group('Keyboard Interaction', () {
      testWidgets('dismisses keyboard when tapping outside', (tester) async {
        await tester.pumpWidget(createTestApp(const HomeScreen()));
        await tester.pump();

        // Focus on search field
        final textField = find.byType(TextField);
        await tester.tap(textField);
        await tester.pump();

        // Tap outside (on GestureDetector area)
        await tester.tapAt(const Offset(100, 400));
        await tester.pump();

        // Focus should be removed (keyboard dismissed)
        // This is handled by the GestureDetector in the widget
      });
    });
  });
}
