import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/data_service.dart';
import '../../core/services/sync_manager.dart';
import 'main_navigation.dart';
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
    // Initialize sync manager
    await syncManager.initialize();

    await Future.delayed(const Duration(seconds: 2));

    final allPasal = await DataService.getAllPasal();

    if (mounted) {
      if (allPasal.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      } else {
        // Check for updates in background (non-blocking)
        syncManager.checkOnLaunch();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      }
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
