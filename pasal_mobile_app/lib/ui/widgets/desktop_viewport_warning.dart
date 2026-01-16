import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A widget that shows a warning banner when viewing the app on a wide screen (desktop/laptop)
/// Only shows on web platform and when the screen width exceeds the mobile threshold
class DesktopViewportWarning extends StatefulWidget {
  final Widget child;

  /// Width threshold above which the warning is shown (default: 600px)
  final double widthThreshold;

  const DesktopViewportWarning({
    super.key,
    required this.child,
    this.widthThreshold = 600,
  });

  @override
  State<DesktopViewportWarning> createState() => _DesktopViewportWarningState();
}

class _DesktopViewportWarningState extends State<DesktopViewportWarning> {
  static const String _dismissedKey = 'desktop_warning_dismissed';
  bool _isDismissed = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDismissedState();
  }

  Future<void> _loadDismissedState() async {
    if (!kIsWeb) {
      setState(() {
        _isDismissed = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(_dismissedKey) ?? false;
      if (mounted) {
        setState(() {
          _isDismissed = dismissed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _dismissWarning() async {
    setState(() {
      _isDismissed = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dismissedKey, true);
    } catch (e) {
      // Ignore storage errors
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show on non-web platforms
    if (!kIsWeb) {
      return widget.child;
    }

    // Wait for loading
    if (_isLoading) {
      return widget.child;
    }

    // Don't show if dismissed
    if (_isDismissed) {
      return widget.child;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final shouldShowWarning = screenWidth > widget.widthThreshold;

    if (!shouldShowWarning) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use Column instead of Stack to avoid Overlay issues
    return Column(
      children: [
        // Warning banner at top
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.amber.shade900.withAlpha(220)
                : Colors.amber.shade100,
            border: Border(
              bottom: BorderSide(
                color: Colors.amber.shade700.withAlpha(100),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(
                  Icons.phone_android_rounded,
                  color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Tampilan Terbaik di Ponsel — ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark
                                ? Colors.amber.shade100
                                : Colors.amber.shade900,
                          ),
                        ),
                        TextSpan(
                          text: 'Aplikasi ini dioptimalkan untuk mobile.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.amber.shade200
                                : Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Use GestureDetector instead of IconButton to avoid Overlay requirement
                GestureDetector(
                  onTap: _dismissWarning,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color:
                          (isDark
                                  ? Colors.amber.shade800
                                  : Colors.amber.shade200)
                              .withAlpha(100),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: isDark
                          ? Colors.amber.shade200
                          : Colors.amber.shade800,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Main content
        Expanded(child: widget.child),
      ],
    );
  }
}
