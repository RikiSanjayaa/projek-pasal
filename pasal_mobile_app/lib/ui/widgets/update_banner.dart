import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/sync_manager.dart';
import '../../core/services/sync_progress.dart';
import 'app_notification.dart';

/// Banner widget that shows when updates are available
/// Modern, glass-like design with auto-dismiss functionality
class UpdateBanner extends StatefulWidget {
  final VoidCallback? onSyncComplete;

  const UpdateBanner({super.key, this.onSyncComplete});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _syncController; // Controller for rotation animation
  late Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;

  // Track state locally to avoid rebuilding conflicts
  bool _isDismissedByTimer = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Initial check
    _checkVisibility();

    // Listeners
    syncManager.updateAvailable.addListener(_checkVisibility);
    syncManager.state.addListener(_checkVisibility);
  }

  @override
  void dispose() {
    syncManager.updateAvailable.removeListener(_checkVisibility);
    syncManager.state.removeListener(_checkVisibility);
    _animationController.dispose();
    _syncController.dispose();
    _cancelTimer();
    super.dispose();
  }

  void _checkVisibility() {
    final hasUpdate = syncManager.updateAvailable.value;
    final isSyncing = syncManager.state.value == SyncState.syncing;
    final shouldShow = hasUpdate || isSyncing;

    if (shouldShow) {
      if (_animationController.status != AnimationStatus.completed &&
          _animationController.status != AnimationStatus.forward) {
        _animationController.forward();
      }

      if (hasUpdate && !isSyncing && !_isDismissedByTimer) {
        _startAutoDismissTimer();
      } else if (isSyncing) {
        _cancelTimer();
      }
    } else {
      if (_animationController.status != AnimationStatus.dismissed &&
          _animationController.status != AnimationStatus.reverse) {
        _animationController.reverse();
      }
      _cancelTimer();
    }
  }

  void _startAutoDismissTimer() {
    // Prevent stacking timers
    if (_autoDismissTimer != null) return;

    _autoDismissTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        _isDismissedByTimer = true;
        // Functionally dismiss in manager, which triggers listeners to close UI
        syncManager.dismissUpdate();
      }
    });
  }

  void _cancelTimer() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }

  void _handleSync() async {
    _cancelTimer();
    final result = await syncManager.performSync();

    if (mounted) {
      if (result.success) {
        AppNotification.show(
          context,
          "Update berhasil!",
          color: AppColors.success,
          icon: Icons.check_circle_rounded,
        );
        widget.onSyncComplete?.call();
      } else if (syncManager.progress.value?.phase == SyncPhase.cancelled) {
        AppNotification.show(
          context,
          "Update dibatalkan",
          color: AppColors.warning,
          icon: Icons.close_rounded,
        );
      } else {
        AppNotification.show(
          context,
          result.message,
          color: AppColors.error,
          icon: Icons.error_rounded,
        );
      }
    }
  }

  void _confirmCancel() {
    _cancelTimer();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Batalkan?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Proses download akan dihentikan."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (syncManager.updateAvailable.value) _startAutoDismissTimer();
            },
            child: Text(
              "Lanjut Download",
              style: TextStyle(color: AppColors.primary),
            ),
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
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        if (_animationController.value == 0) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isSyncing = syncManager.state.value == SyncState.syncing;

        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0, -0.5),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeOutBack,
                ),
              ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: isSyncing
                    ? _buildSyncingContent(isDark)
                    : _buildUpdateAvailableContent(isDark),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpdateAvailableContent(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.system_update_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Update Baru",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Tersedia data terbaru",
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              _cancelTimer();
              syncManager.dismissUpdate();
            },
            style: TextButton.styleFrom(
              foregroundColor: subTextColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text("Nanti", style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              _cancelTimer();
              _handleSync();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              shape: const StadiumBorder(),
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 36),
            ),
            child: const Text(
              "Update",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncingContent(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return ValueListenableBuilder<SyncProgress?>(
      valueListenable: syncManager.progress,
      builder: (context, progress, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  RotationTransition(
                    turns: _syncController,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.sync,
                        color: AppColors.primary,
                        size: 20,
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
                              ? "Memperbarui..."
                              : "Mengunduh...",
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (progress?.currentOperation != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              progress!.currentOperation,
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _confirmCancel,
                    icon: Icon(
                      Icons.close_rounded,
                      color: subTextColor,
                      size: 20,
                    ),
                    tooltip: "Batalkan",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress?.progress,
                  minHeight: 4,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${progress?.progressPercent ?? 0}%",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (progress?.downloadedBytesFormatted != null)
                    Text(
                      progress!.downloadedBytesFormatted,
                      style: TextStyle(color: subTextColor, fontSize: 10),
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
            return const SizedBox.shrink();
          case SyncState.syncing:
            return ValueListenableBuilder<SyncProgress?>(
              valueListenable: syncManager.progress,
              builder: (context, progress, child) {
                return Tooltip(
                  message: "Sinkronisasi ${progress?.progressPercent ?? 0}%",
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: progress?.progress,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
            );
          case SyncState.error:
            return const Tooltip(
              message: "Gagal sinkronisasi",
              child: Icon(
                Icons.sync_problem_rounded,
                color: AppColors.warning,
                size: 20,
              ),
            );
          case SyncState.idle:
            return ValueListenableBuilder<bool>(
              valueListenable: syncManager.updateAvailable,
              builder: (context, hasUpdate, child) {
                if (hasUpdate) {
                  return Tooltip(
                    message: "Update tersedia",
                    child: Icon(
                      Icons.system_update_rounded,
                      color: AppColors.primary,
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
