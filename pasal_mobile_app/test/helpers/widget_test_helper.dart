import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/models/pasal_model.dart';
import 'package:pasal_mobile_app/models/undang_undang_model.dart';
import '../mocks/shared_preferences_mock.dart';

/// Creates a test app wrapper with MaterialApp and necessary providers.
Widget createTestApp(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    home: child,
    themeMode: themeMode,
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
  );
}

/// Creates a test app with Scaffold wrapper for widgets that need it.
Widget createTestAppWithScaffold(
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    home: Scaffold(body: child),
    themeMode: themeMode,
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
  );
}

/// Sets up common mocks for widget tests.
void setUpWidgetTests() {
  setupMockSharedPreferences({});
  setupMockClipboard();
}

/// Sets up mock clipboard for tests.
void setupMockClipboard() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (message) async {
    if (message.method == 'Clipboard.setData') {
      return null; // Success
    }
    if (message.method == 'Clipboard.getData') {
      return <String, dynamic>{'text': ''};
    }
    return null;
  });
}

/// Test data factory for creating mock models in widget tests.
class WidgetTestData {
  static UndangUndangModel createUU({
    String id = 'uu-1',
    String kode = 'KUHP',
    String nama = 'Kitab Undang-Undang Hukum Pidana',
    String? namaLengkap,
    String? deskripsi,
    int tahun = 2023,
    bool isActive = true,
    DateTime? updatedAt,
  }) {
    return UndangUndangModel(
      id: id,
      kode: kode,
      nama: nama,
      namaLengkap: namaLengkap,
      deskripsi: deskripsi,
      tahun: tahun,
      isActive: isActive,
      updatedAt: updatedAt ?? DateTime(2024, 1, 1),
    );
  }

  static PasalModel createPasal({
    String id = 'pasal-1',
    String undangUndangId = 'uu-1',
    String nomor = '1',
    String isi = 'Isi pasal untuk testing widget',
    String? penjelasan,
    String? judul,
    List<String> keywords = const [],
    List<String> relatedIds = const [],
    bool isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PasalModel(
      id: id,
      undangUndangId: undangUndangId,
      nomor: nomor,
      isi: isi,
      penjelasan: penjelasan,
      judul: judul,
      keywords: keywords,
      relatedIds: relatedIds,
      isActive: isActive,
      createdAt: createdAt ?? DateTime(2024, 1, 1),
      updatedAt: updatedAt ?? DateTime(2024, 1, 1),
    );
  }

  static List<UndangUndangModel> createUUList(int count) {
    final codes = ['KUHP', 'KUHAP', 'KUHPer', 'ITE', 'NARKOTIKA'];
    return List.generate(
      count,
      (i) => createUU(
        id: 'uu-$i',
        kode: codes[i % codes.length],
        nama: 'Undang-Undang ${codes[i % codes.length]}',
        tahun: 2020 + i,
      ),
    );
  }

  static List<PasalModel> createPasalList(int count, {String uuId = 'uu-1'}) {
    return List.generate(
      count,
      (i) => createPasal(
        id: 'pasal-$i',
        undangUndangId: uuId,
        nomor: '${i + 1}',
        isi: 'Isi pasal ${i + 1} untuk testing widget dengan konten yang cukup panjang.',
        keywords: ['keyword${i % 3}', 'test'],
      ),
    );
  }
}

/// Custom finder for finding widgets by semantic label.
Finder findBySemanticLabel(String label) {
  return find.bySemanticsLabel(label);
}

/// Waits for async operations to complete.
Future<void> pumpAndSettleWithTimeout(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    timeout,
  );
}

/// Extension on WidgetTester for common operations.
extension WidgetTesterExtensions on WidgetTester {
  /// Enters text into a TextField and triggers onChanged.
  Future<void> enterTextAndSettle(Finder finder, String text) async {
    await enterText(finder, text);
    await pump();
  }

  /// Taps a widget and waits for animations to settle.
  Future<void> tapAndSettle(Finder finder) async {
    await tap(finder);
    await pumpAndSettle();
  }

  /// Scrolls until a widget is visible.
  Future<void> scrollUntilVisible(
    Finder finder,
    Finder scrollable, {
    double delta = 100,
  }) async {
    while (finder.evaluate().isEmpty) {
      await drag(scrollable, Offset(0, -delta));
      await pump();
    }
  }
}
