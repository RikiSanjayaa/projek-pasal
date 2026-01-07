import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/sync_manager.dart';
import '../../core/services/sync_progress.dart';
import 'app_notification.dart';

/// Banner widget that shows when updates are available
/// Now with detailed progress tracking during sync
class UpdateBanner extends StatefulWidget {
  final VoidCallback? onSyncComplete;

  const UpdateBanner({super.key, this.onSyncComplete});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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

  void _handleSync() async {
    final result = await syncManager.performSync();

    if (mounted) {
      if (result.success) {
        AppNotification.show(
          context,
          "Sinkronisasi selesai",
          color: AppColors.success,
          icon: Icons.check_circle,
        );
        widget.onSyncComplete?.call();
      } else if (syncManager.progress.value?.phase == SyncPhase.cancelled) {
        AppNotification.show(
          context,
          "Sinkronisasi dibatalkan",
          color: AppColors.warning,
          icon: Icons.cancel,
        );
      } else {
        AppNotification.show(
          context,
          result.message,
          color: AppColors.error,
          icon: Icons.error_outline,
        );
      }
    }
  }

  void _confirmCancel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Batalkan Sinkronisasi?",
          style: TextStyle(
            color: AppColors.textPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Sinkronisasi akan dihentikan. Anda dapat mencoba lagi nanti.",
          style: TextStyle(color: AppColors.textSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary(isDark),
            ),
            child: const Text("Lanjutkan"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              syncManager.cancelSync();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("Batalkan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<bool>(
      valueListenable: syncManager.updateAvailable,
      builder: (context, updateAvailable, child) {
        return ValueListenableBuilder<SyncState>(
          valueListenable: syncManager.state,
          builder: (context, syncState, child) {
            final shouldShow =
                updateAvailable || syncState == SyncState.syncing;

            if (shouldShow) {
              _animationController.forward();
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
                                  AppColors.primary.withValues(alpha: 0.8),
                                  AppColors.primary.withValues(alpha: 0.6),
                                ]
                              : [
                                  AppColors.primary.withValues(alpha: 0.8),
                                  AppColors.primary.withValues(alpha: 0.6),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: syncState == SyncState.syncing
                            ? _buildSyncingContent()
                            : _buildUpdateAvailableContent(),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildUpdateAvailableContent() {
    return Padding(
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
              Icons.system_update,
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
                const Text(
                  "Update Tersedia",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Data terakhir: ${syncManager.lastSyncText}",
                  style: TextStyle(
                    color: Colors.white.withAlpha(204),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => syncManager.dismissUpdate(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withAlpha(179),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text("Nanti"),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: _handleSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Update",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncingContent() {
    return ValueListenableBuilder<SyncProgress?>(
      valueListenable: syncManager.progress,
      builder: (context, progress, child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          progress?.isIncremental == true
                              ? "Memperbarui Data..."
                              : "Mengunduh Data...",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          progress?.currentOperation ?? "Mempersiapkan...",
                          style: TextStyle(
                            color: Colors.white.withAlpha(204),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Cancel button
                  IconButton(
                    onPressed: _confirmCancel,
                    icon: Icon(
                      Icons.close,
                      color: Colors.white.withAlpha(179),
                      size: 20,
                    ),
                    tooltip: "Batalkan",
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress?.progress,
                  minHeight: 6,
                  backgroundColor: Colors.white.withAlpha(51),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${progress?.progressPercent ?? 0}%",
                    style: TextStyle(
                      color: Colors.white.withAlpha(204),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (progress?.downloadedBytesFormatted != null)
                    Text(
                      progress!.downloadedBytesFormatted,
                      style: TextStyle(
                        color: Colors.white.withAlpha(179),
                        fontSize: 11,
                      ),
                    ),
                  if (progress?.estimatedRemainingFormatted != null)
                    Text(
                      progress!.estimatedRemainingFormatted!,
                      style: TextStyle(
                        color: Colors.white.withAlpha(179),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact sync status indicator for app bar or other places
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: syncManager.state,
      builder: (context, state, child) {
        switch (state) {
          case SyncState.checking:
            return const Tooltip(
              message: "Memeriksa update...",
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          case SyncState.syncing:
            return ValueListenableBuilder<SyncProgress?>(
              valueListenable: syncManager.progress,
              builder: (context, progress, child) {
                return Tooltip(
                  message: "Sinkronisasi ${progress?.progressPercent ?? 0}%",
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: progress?.progress,
                    ),
                  ),
                );
              },
            );
          case SyncState.error:
            return const Tooltip(
              message: "Gagal sinkronisasi",
              child: Icon(
                Icons.sync_problem,
                color: AppColors.warning,
                size: 20,
              ),
            );
          case SyncState.idle:
            return ValueListenableBuilder<bool>(
              valueListenable: syncManager.updateAvailable,
              builder: (context, hasUpdate, child) {
                if (hasUpdate) {
                  return const Tooltip(
                    message: "Update tersedia",
                    child: Icon(
                      Icons.system_update,
                      color: AppColors.info,
                      size: 20,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            );
        }
      },
    );
  }
}
