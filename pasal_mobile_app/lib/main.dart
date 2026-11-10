import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'core/config/app_colors.dart';
import 'core/config/app_theme.dart';
import 'core/services/data_service.dart';
import 'core/utils/theme_color_sync.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/widgets/auth_wrapper.dart';
import 'core/config/theme_controller.dart';
import 'package:showcaseview/showcaseview.dart';

/// Global navigator key for navigation from anywhere (e.g., AuthWrapper)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  await DataService.initialize();

  // Register ShowcaseView globally (v5.0.0+ API)
  ShowcaseView.register();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'CariPasal',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          locale: const Locale('id'),
          supportedLocales: const [Locale('id'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const SplashScreen(),
          builder: (context, child) {
            // Samakan status bar Android/PWA dan latar browser dengan tema
            // aplikasi (termasuk saat mode Sistem mengikuti preferensi OS).
            final isDark = Theme.of(context).brightness == Brightness.dark;
            syncBrowserTheme(
              statusBarColor: cssColorHex(AppColors.appBar(isDark)),
              backgroundColor: cssColorHex(AppColors.scaffold(isDark)),
              isDark: isDark,
            );

            // Wrap all routes with AuthWrapper to handle forced logout
            // MaterialUiCompatibilityBridge: showcaseview (dan printing) masih
            // mengimpor package:flutter/material.dart, jadi tema & lokalisasi
            // perlu diteruskan ke widget lama tersebut.
            // ignore: deprecated_member_use
            return MaterialUiCompatibilityBridge(
              child: AuthWrapper(child: child ?? const SizedBox.shrink()),
            );
          },
        );
      },
    );
  }
}
