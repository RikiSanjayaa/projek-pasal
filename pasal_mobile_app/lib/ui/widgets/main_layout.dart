import 'package:flutter/material.dart';
import '../../core/config/theme_controller.dart';
import '../../core/config/app_colors.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final Widget? endDrawer;

  const MainLayout({
    super.key,
    required this.child,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.appBar,
    this.backgroundColor,
    this.endDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        // Use Theme.of(context).brightness to properly handle system theme
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: backgroundColor ?? AppColors.scaffold(isDark),
          appBar: appBar,
          body: SafeArea(child: child),
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
          endDrawer: endDrawer,
        );
      },
    );
  }
}
