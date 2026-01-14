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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
    _checkDataAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkDataAndNavigate() async {
    // Initialize services
    await syncManager.initialize();
    // Allow animation to play a bit before heavy lifting
    await Future.delayed(const Duration(milliseconds: 500));
    await authService.initialize();

    // Ensure splash stays for at least 3 seconds total for branding visibility
    await Future.delayed(const Duration(seconds: 3));

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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A), // Slate 900
                    const Color(0xFF1E293B), // Slate 800
                  ]
                : [
                    const Color(0xFFFFFFFF),
                    const Color(0xFFF8FAFC), // Slate 50
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 1. University Logo - Top Center
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Center(
                    child: Image.asset(
                      isDark
                          ? 'assets/images/logo-ubg putih.png'
                          : 'assets/images/logo-ubg hitam.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // 2. Main Content - Center
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Logo - Floating with Glow
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.25),
                                blurRadius: 80,
                                spreadRadius: -5,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            isDark
                                ? 'assets/images/logo-dark.png'
                                : 'assets/images/logo.png',
                            height: 130,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Title
                        Text(
                          "CariPasal",
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                            letterSpacing: 1.5,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Subtitle - Elegant & Thin
                        Text(
                          "PENCARIAN PASAL HUKUM INDONESIA",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                            letterSpacing: 2.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Loading - Bottom
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark
                              ? Colors.white54
                              : AppColors.primary.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
