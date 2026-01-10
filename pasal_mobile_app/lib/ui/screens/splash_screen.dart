import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/query_service.dart';
import '../../core/services/sync_manager.dart';
import '../widgets/main_navigation.dart';
import 'login_screen.dart';
import 'lock_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkDataAndNavigate();
  }

  Future<void> _checkDataAndNavigate() async {
    // Initialize services
    await syncManager.initialize();
    await authService.initialize();

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 1. Check if user is logged in
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Not logged in - go to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // 2. Check local expiry (works offline)
    final expiryResult = await authService.checkExpiryOffline();
    if (!mounted) return;

    if (expiryResult == ExpiryCheckResult.expired) {
      // Expired - show lock screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LockScreen()),
      );
      return;
    }

    // 3. Check if we have local data
    final allPasal = await QueryService.getAllPasal();

    if (!mounted) return;

    if (allPasal.isEmpty) {
      // No data - need to download
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else {
      // Has data - go to main app
      // Check for updates in background (non-blocking)
      syncManager.checkOnLaunch();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scaffold(isDark),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo container with glow effect
            Container(
              width: 120,
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: isDark
                    ? Image.asset(
                        'assets/images/logo-dark.png',
                        fit: BoxFit.contain,
                      )
                    : Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              "CariPasal",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Pencarian Pasal Hukum Indonesia",
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(isDark),
              ),
            ),

            const SizedBox(height: 48),

            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Menyiapkan data hukum...",
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
