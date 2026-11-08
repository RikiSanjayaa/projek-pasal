import 'package:web/web.dart' as web;

String? _lastStatusBarColor;
String? _lastBackgroundColor;
bool? _lastIsDark;

/// Terapkan tema aplikasi ke UI browser:
/// - semua `<meta name="theme-color">` → warna status bar Android/PWA,
/// - `background-color` root/body → latar saat Flutter belum menggambar,
/// - `color-scheme` → scrollbar & kontrol bawaan browser.
///
/// Nilai terakhir di-cache karena fungsi ini dipanggil dari `MaterialApp.builder`
/// pada setiap rebuild tema.
void syncBrowserTheme({
  required String statusBarColor,
  required String backgroundColor,
  required bool isDark,
}) {
  if (_lastStatusBarColor != statusBarColor) {
    _lastStatusBarColor = statusBarColor;
    final metas = web.document.querySelectorAll('meta[name="theme-color"]');
    for (var i = 0; i < metas.length; i++) {
      final meta = metas.item(i);
      if (meta == null) continue;
      (meta as web.HTMLMetaElement).content = statusBarColor;
    }
  }

  if (_lastBackgroundColor != backgroundColor) {
    _lastBackgroundColor = backgroundColor;
    final root = web.document.documentElement;
    if (root != null) {
      (root as web.HTMLElement).style.setProperty(
        'background-color',
        backgroundColor,
      );
    }
    web.document.body?.style.setProperty('background-color', backgroundColor);
  }

  if (_lastIsDark != isDark) {
    _lastIsDark = isDark;
    final root = web.document.documentElement;
    if (root != null) {
      (root as web.HTMLElement).style.setProperty(
        'color-scheme',
        isDark ? 'dark' : 'light',
      );
    }
  }
}
