import 'package:flutter/material.dart';
import '../../core/services/data_service.dart';
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
    await Future.delayed(const Duration(seconds: 2));

    final allPasal = DataService.getAllPasal();

    if (mounted) {
      if (allPasal.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      }
    }
  }

  // Future<void> _startSyncProcess() async {

  //   await DataService.syncData();
  //   if (mounted) {
  //     Navigator.pushReplacement(
  //       context,
  //       MaterialPageRoute(builder: (context) => const MainNavigation()),
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120, 
              height: 120,
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/images/logo.png'),
                  fit: BoxFit.contain,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "CariPasal",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue, 
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 48),

            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              "Menyiapkan data hukum...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}