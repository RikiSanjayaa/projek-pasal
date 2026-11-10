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
  static const double borderWidth = 1;
  static const double focusBorderWidth = 2;

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.accent(isDark),
          onPrimary: isDark ? const Color(0xFF10243B) : Colors.white,
          secondary: AppColors.secondary,
          error: AppColors.error,
          surface: AppColors.card(isDark),
          onSurface: AppColors.textPrimary(isDark),
          onSurfaceVariant: AppColors.textSecondary(isDark),
          outline: AppColors.border(isDark),
          outlineVariant: AppColors.border(isDark),
          surfaceTint: Colors.transparent,
          primaryContainer: AppColors.selected(isDark),
          onPrimaryContainer: AppColors.accent(isDark),
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
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusControl),
      borderSide: BorderSide(
        color: AppColors.border(isDark),
        width: borderWidth,
      ),
    );
    final focusBorder = inputBorder.copyWith(
      borderSide: BorderSide(
        color: AppColors.accent(isDark),
        width: focusBorderWidth,
      ),
    );
    final focusSide = WidgetStateProperty.resolveWith<BorderSide>(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: AppColors.accent(isDark), width: focusBorderWidth)
          : BorderSide.none,
    );
    final filledFocusSide = WidgetStateProperty.resolveWith<BorderSide>(
      (states) => states.contains(WidgetState.focused)
          ? const BorderSide(color: Colors.white, width: focusBorderWidth)
          : BorderSide.none,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.scaffold(isDark),
      cardColor: AppColors.card(isDark),
      dividerColor: AppColors.border(isDark),
      hoverColor: AppColors.accent(isDark).withValues(alpha: .06),
      focusColor: AppColors.accent(isDark).withValues(alpha: .14),
      textTheme: _textTheme(isDark),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.appBar(isDark),
        foregroundColor: AppColors.textPrimary(isDark),
        elevation: 0,
        scrolledUnderElevation: 0, // M3 menggeser warna saat scroll
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.border(isDark),
            width: borderWidth,
          ),
        ),
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
        selectedColor: AppColors.selected(isDark),
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
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
        ).copyWith(side: filledFocusSide),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
        ).copyWith(side: filledFocusSide),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size(64, 48),
              padding: buttonPadding,
              shape: buttonShape,
              side: BorderSide(color: AppColors.border(isDark)),
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? BorderSide(
                        color: AppColors.accent(isDark),
                        width: focusBorderWidth,
                      )
                    : BorderSide(
                        color: AppColors.border(isDark),
                        width: borderWidth,
                      ),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: buttonShape,
        ).copyWith(side: focusSide),
      ),
      iconButtonTheme: IconButtonThemeData(style: ButtonStyle(side: focusSide)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill(isDark),
        hintStyle: TextStyle(color: AppColors.textSecondary(isDark)),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder,
        focusedBorder: focusBorder,
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(
            color: AppColors.error,
            width: borderWidth,
          ),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(
            color: AppColors.error,
            width: focusBorderWidth,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        constraints: const BoxConstraints(maxWidth: 640),
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
        constraints: const BoxConstraints(maxWidth: 560),
        backgroundColor: AppColors.card(isDark),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSheet),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border(isDark),
        thickness: borderWidth,
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
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        )
        .apply(bodyColor: primary, displayColor: primary)
        .copyWith(
          bodySmall: TextStyle(fontSize: 12, height: 1.5, color: secondary),
        );
  }
}
