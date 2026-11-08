/// No-op di platform non-web. Di Android/iOS warna status bar diatur oleh
/// `SystemChrome`/theme native, bukan meta tag browser.
void syncBrowserTheme({
  required String statusBarColor,
  required String backgroundColor,
  required bool isDark,
}) {}
