import 'package:material_ui/material_ui.dart';

// Sinkronisasi warna chrome browser (status bar Android/PWA dan latar halaman
// sebelum Flutter menggambar) dengan tema aplikasi yang sedang aktif.
export 'theme_color_sync_stub.dart'
    if (dart.library.js_interop) 'theme_color_sync_web.dart';

/// Format [color] sebagai hex CSS `#RRGGBB` (alpha diabaikan).
String cssColorHex(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
