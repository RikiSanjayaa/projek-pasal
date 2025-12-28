import 'package:flutter/material.dart';
import '../../core/config/theme_controller.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;

  const MainLayout({
    super.key,
    required this.child,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.appBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        
        return Scaffold(
          backgroundColor: backgroundColor ?? (isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA)),
          appBar: appBar,
          body: SafeArea(child: child),
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
        );
      },
    );
  }
}