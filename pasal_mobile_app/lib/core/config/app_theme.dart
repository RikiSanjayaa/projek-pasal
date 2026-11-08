import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Satu-satunya definisi tema Material 3 untuk CariPasal (terang + gelap).
///
/// Warna merek berasal dari [AppColors]; skema warna dibangun dengan
/// `ColorScheme.fromSeed` lalu merek (primary/secondary) dan permukaan
/// dipaksa ke nilai di [AppColors] agar tampilan tidak bergeser.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static const double radiusControl = 12; // input, tombol kecil
  static const double radiusButton = 14; // tombol utama
  static const double radiusCard = 16; // kartu, panel
  static const double radiusSheet = 20; // bottom sheet, dialog
  static const double radiusChip = 20; // chip pil

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.secondary,
          error: AppColors.error,
          surface: AppColors.card(isDark),
          onSurface: AppColors.textPrimary(isDark),
          onSurfaceVariant: AppColors.textSecondary(isDark),
          outline: AppColors.border(isDark),
          outlineVariant: AppColors.border(isDark),
          surfaceTint: Colors.transparent,
        );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusCard),
      side: BorderSide(color: AppColors.border(isDark)),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusButton),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.scaffold(isDark),
      cardColor: AppColors.card(isDark),
      dividerColor: AppColors.border(isDark),
      textTheme: _textTheme(isDark),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.appBar(isDark),
        foregroundColor: AppColors.textPrimary(isDark),
        elevation: 0,
        scrolledUnderElevation: 0, // M3 menggeser warna saat scroll
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card(isDark),
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.inputFill(isDark),
        selectedColor: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
        side: BorderSide(color: AppColors.border(isDark)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusChip),
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary(isDark),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: buttonPadding,
          shape: buttonShape,
          side: BorderSide(color: AppColors.border(isDark)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: buttonShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill(isDark),
        hintStyle: TextStyle(color: AppColors.textSecondary(isDark)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide.none,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.card(isDark),
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card(isDark),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSheet),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border(isDark),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColors.card(isDark),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  /// Skala teks untuk membaca pasal panjang: badan teks 16/14 dengan tinggi
  /// baris longgar (1.6-1.7), judul rapat.
  static TextTheme _textTheme(bool isDark) {
    final primary = AppColors.textPrimary(isDark);
    final secondary = AppColors.textSecondary(isDark);
    return TextTheme(
      headlineSmall: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleSmall: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.7),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.6),
      bodySmall: const TextStyle(fontSize: 12, height: 1.5),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      labelSmall: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ).apply(bodyColor: primary, displayColor: primary).copyWith(
      bodySmall: TextStyle(fontSize: 12, height: 1.5, color: secondary),
    );
  }
}
