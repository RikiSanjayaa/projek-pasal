import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/env.dart';
import 'core/config/app_colors.dart';
import 'core/services/data_service.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/widgets/auth_wrapper.dart';
import 'core/config/theme_controller.dart';

/// Global navigator key for navigation from anywhere (e.g., AuthWrapper)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  await DataService.initialize();
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
          // Tema Terang
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: AppColors.scaffoldLight,
            primaryColor: AppColors.primary,
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              secondary: AppColors.secondary,
              surface: AppColors.cardLight,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.appBarLight,
              foregroundColor: Colors.black,
              elevation: 0,
              scrolledUnderElevation: 0, // Fix M3 color change on scroll
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.inputFillLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          // Tema Gelap
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.scaffoldDark,
            cardColor: AppColors.cardDark,
            primaryColor: AppColors.primary,
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              secondary: AppColors.secondary,
              surface: AppColors.cardDark,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.appBarDark,
              foregroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0, // Fix M3 color change on scroll
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.inputFillDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintStyle: TextStyle(color: Colors.grey[500]),
            ),
          ),
          home: const SplashScreen(),
          builder: (context, child) {
            // Wrap all routes with AuthWrapper to handle forced logout
            return AuthWrapper(child: child ?? const SizedBox.shrink());
          },
        );
      },
    );
  }
}
