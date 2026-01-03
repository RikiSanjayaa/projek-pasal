import 'package:flutter/material.dart';
import '../../core/config/theme_controller.dart';
import '../../core/services/sync_manager.dart';

/// A reusable end drawer widget for settings that can be used across all screens.
/// Usage: Add this as the endDrawer of your Scaffold and use a hamburger icon
/// to open it with Scaffold.of(context).openEndDrawer()
class SettingsDrawer extends StatefulWidget {
  const SettingsDrawer({super.key});

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
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
                                        content: const Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text("Data sudah up-to-date"),
                                          ],
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                              color: isDark
                                  ? Colors.grey[850]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
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
                                          color: Colors.blue,
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
                                        isSyncing
                                            ? 'Menyinkronkan...'
                                            : 'Periksa Update',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.grey[800],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        syncManager.lastSyncTime != null
                                            ? 'Terakhir: ${syncManager.lastSyncText}'
                                            : 'Belum pernah sync',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey[500]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isSyncing)
                                  Icon(
                                    Icons.chevron_right,
                                    color: isDark
                                        ? Colors.grey[600]
                                        : Colors.grey[400],
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
