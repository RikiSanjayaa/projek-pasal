import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/auth_service.dart';

/// Banner widget that shows when user's account is expiring soon (within 30 days)
class ExpiryWarningBanner extends StatefulWidget {
  const ExpiryWarningBanner({super.key});

  @override
  State<ExpiryWarningBanner> createState() => _ExpiryWarningBannerState();
}

class _ExpiryWarningBannerState extends State<ExpiryWarningBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<int?>(
      valueListenable: authService.daysUntilExpiry,
      builder: (context, days, _) {
        // Only show if expiry is within 30 days and not dismissed
        final shouldShow = days != null && days <= 30 && days >= 0 && !_dismissed;

        if (shouldShow) {
          _animationController.forward();
        } else if (_dismissed) {
          // Keep hidden if dismissed
        } else {
          _animationController.reverse();
        }

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            if (_animationController.value == 0) {
              return const SizedBox.shrink();
            }

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -1),
                end: Offset.zero,
              ).animate(_animationController),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              AppColors.warning.withValues(alpha: 0.9),
                              AppColors.warning.withValues(alpha: 0.7),
                            ]
                          : [
                              AppColors.warning.withValues(alpha: 0.9),
                              AppColors.warning.withValues(alpha: 0.7),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.timer_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getTitle(days ?? 0),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Hubungi administrator untuk perpanjang",
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(204),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _dismiss,
                            icon: Icon(
                              Icons.close,
                              color: Colors.white.withAlpha(179),
                              size: 20,
                            ),
                            tooltip: "Tutup",
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getTitle(int days) {
    if (days == 0) {
      return "Akun kedaluwarsa hari ini!";
    } else if (days == 1) {
      return "Akun kedaluwarsa besok!";
    } else if (days <= 7) {
      return "Akun kedaluwarsa dalam $days hari!";
    } else {
      return "Akun akan kedaluwarsa dalam $days hari";
    }
  }
}
