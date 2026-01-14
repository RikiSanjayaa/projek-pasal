import 'package:flutter/material.dart';
import '../../core/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_colors.dart';
import '../../core/config/theme_controller.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_manager.dart';
import '../../core/services/sync_progress.dart';
import '../screens/login_screen.dart';
import 'app_notification.dart';

/// A reusable end drawer widget for settings that can be used across all screens.
/// Usage: Add this as the endDrawer of your Scaffold and use a hamburger icon
/// to open it with Scaffold.of(context).openEndDrawer()
class SettingsDrawer extends StatefulWidget {
  const SettingsDrawer({super.key});

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  bool _successFeedback = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Drawer(
      width: screenWidth * 0.85, // 85% of screen width
      backgroundColor: AppColors.scaffold(isDark),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border(isDark)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      size: 24,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengaturan',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey[800],
                          ),
                        ),
                        Text(
                          'CariPasal v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.icon(isDark)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User section
                    Text(
                      'Akun',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<String?>(
                      valueListenable: authService.userName,
                      builder: (context, userName, _) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill(isDark),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              // User avatar
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // User info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName ?? 'Pengguna',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary(isDark),
                                      ),
                                    ),
                                    Text(
                                      authService.currentUserEmail ?? '',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    // Action buttons row
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactActionButton(
                            icon: Icons.lock_reset_rounded,
                            onTap: () =>
                                _showResetPasswordDialog(context, isDark),
                            isDark: isDark,
                            label: 'Ganti Password',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactActionButton(
                            icon: Icons.logout_rounded,
                            onTap: () => _confirmLogout(context, isDark),
                            isDark: isDark,
                            isDestructive: true,
                            label: 'Keluar',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Theme section
                    Text(
                      'Tema Aplikasi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeController,
                      builder: (context, mode, _) {
                        return Row(
                          children: [
                            _buildThemeOption(
                              icon: Icons.brightness_auto_rounded,
                              label: 'Sistem',
                              isSelected: mode == ThemeMode.system,
                              onTap: () =>
                                  themeController.setTheme(ThemeMode.system),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildThemeOption(
                              icon: Icons.light_mode_rounded,
                              label: 'Terang',
                              isSelected: mode == ThemeMode.light,
                              onTap: () =>
                                  themeController.setTheme(ThemeMode.light),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildThemeOption(
                              icon: Icons.dark_mode_rounded,
                              label: 'Gelap',
                              isSelected: mode == ThemeMode.dark,
                              onTap: () =>
                                  themeController.setTheme(ThemeMode.dark),
                              isDark: isDark,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Sync section
                    Text(
                      'Sinkronisasi Data',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<bool>(
                      valueListenable: syncManager.updateAvailable,
                      builder: (context, updateAvailable, _) {
                        return ValueListenableBuilder<SyncState>(
                          valueListenable: syncManager.state,
                          builder: (context, state, _) {
                            return ValueListenableBuilder<SyncProgress?>(
                              valueListenable: syncManager.progress,
                              builder: (context, progress, _) {
                                final isSyncing = state == SyncState.syncing;
                                final isChecking = state == SyncState.checking;
                                final isBusy = isSyncing || isChecking;

                                // Determine UI state
                                final bool showSuccess =
                                    _successFeedback && !isBusy;
                                final bool showUpdateAvailable =
                                    updateAvailable && !isBusy && !showSuccess;

                                return GestureDetector(
                                  onTap: isBusy
                                      ? null
                                      : () async {
                                          if (showUpdateAvailable) {
                                            Navigator.pop(context);
                                            syncManager.performSync();
                                          } else {
                                            final hasUpdate = await syncManager
                                                .forceCheckUpdates();
                                            if (mounted) {
                                              if (!hasUpdate) {
                                                setState(() {
                                                  _successFeedback = true;
                                                });
                                                Future.delayed(
                                                  const Duration(seconds: 3),
                                                  () {
                                                    if (mounted) {
                                                      setState(() {
                                                        _successFeedback =
                                                            false;
                                                      });
                                                    }
                                                  },
                                                );
                                              } else {
                                                Navigator.pop(context);
                                              }
                                            }
                                          }
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.primary.withValues(
                                              alpha: 0.1,
                                            )
                                          : AppColors.primary.withValues(
                                              alpha: 0.05,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: showUpdateAvailable
                                          ? Border.all(
                                              color: AppColors.primary
                                                  .withAlpha(100),
                                            )
                                          : null,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: showSuccess
                                                    ? Colors.green.withValues(
                                                        alpha: 0.1,
                                                      )
                                                    : AppColors.primary
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: isBusy
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : Icon(
                                                      showSuccess
                                                          ? Icons.check_circle
                                                          : (showUpdateAvailable
                                                                ? Icons
                                                                      .system_update
                                                                : Icons
                                                                      .sync_rounded),
                                                      color: showSuccess
                                                          ? AppColors.success
                                                          : AppColors.primary,
                                                      size: 20,
                                                    ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    showSuccess
                                                        ? 'Data Sudah Terbaru'
                                                        : (isChecking
                                                              ? 'Memeriksa...'
                                                              : (isSyncing
                                                                    ? 'Sinkronisasi...'
                                                                    : (showUpdateAvailable
                                                                          ? 'Update Tersedia'
                                                                          : 'Periksa Update'))),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: showSuccess
                                                          ? AppColors.success
                                                          : AppColors.textPrimary(
                                                              isDark,
                                                            ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    isSyncing
                                                        ? (progress
                                                                  ?.currentOperation ??
                                                              'Memproses...')
                                                        : (syncManager.lastSyncTime !=
                                                                  null
                                                              ? 'Terakhir: ${syncManager.lastSyncText}'
                                                              : 'Belum pernah sync'),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? Colors.grey[500]
                                                          : Colors.grey[600],
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isSyncing)
                                              IconButton(
                                                icon: Icon(
                                                  Icons.close_rounded,
                                                  color: isDark
                                                      ? Colors.grey[500]
                                                      : Colors.grey[400],
                                                  size: 20,
                                                ),
                                                onPressed: () =>
                                                    syncManager.cancelSync(),
                                                tooltip: 'Batalkan',
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              )
                                            else if (!isChecking &&
                                                !showSuccess)
                                              Icon(
                                                Icons.chevron_right,
                                                color: isDark
                                                    ? Colors.grey[600]
                                                    : Colors.grey[400],
                                              ),
                                          ],
                                        ),
                                        if (isSyncing && progress != null) ...[
                                          const SizedBox(height: 12),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: progress.progress,
                                              minHeight: 6,
                                              backgroundColor: isDark
                                                  ? Colors.grey[700]
                                                  : Colors.grey[300],
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                    Color
                                                  >(AppColors.primary),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "${progress.progressPercent}%",
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (progress
                                                      .estimatedRemainingFormatted !=
                                                  null)
                                                Text(
                                                  progress
                                                      .estimatedRemainingFormatted!,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.grey[500]
                                                        : Colors.grey[600],
                                                    fontSize: 11,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required String label,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Ganti Password",
          style: TextStyle(
            color: AppColors.textPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Kami akan mengirim email berisi link untuk mengatur password baru ke ${authService.currentUserEmail}",
          style: TextStyle(color: AppColors.textSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary(isDark),
            ),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog only
              // Navigator.pop(context); // Temporarily disabled for testing

              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(
                  authService.currentUserEmail!,
                  redirectTo: '${Env.webAppUrl}/reset-password',
                );

                if (context.mounted) {
                  AppNotification.show(
                    context,
                    'Email reset password telah dikirim',
                    color: AppColors.success,
                    icon: Icons.mark_email_read_rounded,
                  );
                }
              } on AuthException catch (e) {
                String message;
                // Check for rate limit error
                if (e.message.toLowerCase().contains('rate') ||
                    e.message.toLowerCase().contains('limit') ||
                    e.message.toLowerCase().contains('too many')) {
                  message = 'Terlalu banyak permintaan. Coba lagi nanti.';
                } else {
                  message = 'Gagal: ${e.message}';
                }
                if (context.mounted) {
                  AppNotification.show(
                    context,
                    message,
                    color: AppColors.error,
                    icon: Icons.error_outline_rounded,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  AppNotification.show(
                    context,
                    'Gagal mengirim email. Periksa koneksi.',
                    color: AppColors.error,
                    icon: Icons.wifi_off_rounded,
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text("Kirim Email"),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Keluar dari Akun?",
          style: TextStyle(
            color: AppColors.textPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Anda perlu login kembali untuk mengakses aplikasi.",
          style: TextStyle(color: AppColors.textSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary(isDark),
            ),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              // First, complete the logout process before any navigation
              await authService.logout();

              if (!dialogContext.mounted) return;

              // Close dialog first, then navigate using the root navigator
              Navigator.pop(dialogContext);

              // Use pushAndRemoveUntil from the dialog context to clear entire stack
              Navigator.pushAndRemoveUntil(
                dialogContext,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("Keluar"),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05)
                : AppColors.inputFill(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: isDark ? 0.5 : 0.3)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to show settings drawer
/// Use this when you need to open the drawer programmatically from a hamburger icon
void openSettingsDrawer(BuildContext context) {
  Scaffold.of(context).openEndDrawer();
}
