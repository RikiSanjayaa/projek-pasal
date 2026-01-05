import 'package:flutter/material.dart';
import '../../core/config/theme_controller.dart';
import '../../core/services/sync_manager.dart';
import '../../core/services/sync_progress.dart';

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
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      size: 24,
                      color: Colors.blue,
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
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
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
                    // Theme section
                    Text(
                      'Tema Aplikasi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
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
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
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
                                          ? Colors.grey[850]
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                      border: showUpdateAvailable
                                          ? Border.all(
                                              color: Colors.blue.withAlpha(100),
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
                                                    : Colors.blue.withValues(
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
                                                          ? Colors.green
                                                          : Colors.blue,
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
                                                          ? Colors.green
                                                          : (isDark
                                                                ? Colors.white
                                                                : Colors
                                                                      .grey[800]),
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
                                                  >(Colors.blue),
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
                                                  color: Colors.blue,
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
                ? Colors.blue.withValues(alpha: 0.15)
                : (isDark ? Colors.grey[850] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected
                    ? Colors.blue
                    : (isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Colors.blue
                      : (isDark ? Colors.grey[500] : Colors.grey[600]),
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
