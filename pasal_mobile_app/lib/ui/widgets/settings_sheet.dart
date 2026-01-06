import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/config/theme_controller.dart';
import '../../core/services/sync_manager.dart';

/// Reusable Settings Sheet that can be shown from anywhere in the app
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    // Use Theme.of(context) instead of cached widget.isDark to respond to theme changes
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_rounded,
                    size: 24,
                    color: AppColors.textPrimary(isDark),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pengaturan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                ],
              ),
            ),

            // Theme selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          const SizedBox(width: 12),
                          _buildThemeOption(
                            icon: Icons.light_mode_rounded,
                            label: 'Terang',
                            isSelected: mode == ThemeMode.light,
                            onTap: () =>
                                themeController.setTheme(ThemeMode.light),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 12),
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
                ],
              ),
            ),

            // Sync section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sinkronisasi Data',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<SyncState>(
                    valueListenable: syncManager.state,
                    builder: (context, state, _) {
                      final isSyncing =
                          state == SyncState.syncing ||
                          state == SyncState.checking;

                      return GestureDetector(
                        onTap: isSyncing
                            ? null
                            : () async {
                                final hasUpdate = await syncManager
                                    .forceCheckUpdates();
                                if (mounted && !hasUpdate) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: AppColors.iconDark,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text("Data sudah up-to-date"),
                                        ],
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: AppColors.success,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      margin: const EdgeInsets.all(16),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill(isDark),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: isSyncing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.sync_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isSyncing
                                          ? 'Menyinkronkan...'
                                          : 'Periksa Update',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary(isDark),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      syncManager.lastSyncTime != null
                                          ? 'Terakhir: ${syncManager.lastSyncText}'
                                          : 'Belum pernah sync',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isSyncing)
                                Icon(
                                  Icons.chevron_right,
                                  color: AppColors.icon(isDark),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // App info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'CariPasal v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
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
                    : AppColors.textSecondary(isDark),
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
