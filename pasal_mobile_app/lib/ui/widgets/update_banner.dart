import 'package:flutter/material.dart';
import '../../core/services/sync_manager.dart';

/// Banner widget that shows when updates are available
class UpdateBanner extends StatefulWidget {
  final VoidCallback? onSyncComplete;
  
  const UpdateBanner({super.key, this.onSyncComplete});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> with SingleTickerProviderStateMixin {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(result.message),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        widget.onSyncComplete?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(result.message)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ValueListenableBuilder<bool>(
      valueListenable: syncManager.updateAvailable,
      builder: (context, updateAvailable, child) {
        if (updateAvailable) {
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
                        ? [Colors.blue.shade900, Colors.blue.shade800]
                        : [Colors.blue.shade500, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withAlpha(77),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ValueListenableBuilder<SyncState>(
                        valueListenable: syncManager.state,
                        builder: (context, syncState, child) {
                          final isSyncing = syncState == SyncState.syncing;
                          
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(51),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: isSyncing
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(
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
                                    Text(
                                      isSyncing ? "Memperbarui data..." : "Update Tersedia",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isSyncing 
                                        ? "Mohon tunggu sebentar"
                                        : "Data terakhir: ${syncManager.lastSyncText}",
                                      style: TextStyle(
                                        color: Colors.white.withAlpha(204),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isSyncing) ...[
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
                                    foregroundColor: Colors.blue.shade700,
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
                            ],
                          );
                        },
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
            return const Tooltip(
              message: "Sinkronisasi...",
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          case SyncState.error:
            return const Tooltip(
              message: "Gagal sinkronisasi",
              child: Icon(Icons.sync_problem, color: Colors.orange, size: 20),
            );
          case SyncState.idle:
            return ValueListenableBuilder<bool>(
              valueListenable: syncManager.updateAvailable,
              builder: (context, hasUpdate, child) {
                if (hasUpdate) {
                  return const Tooltip(
                    message: "Update tersedia",
                    child: Icon(Icons.system_update, color: Colors.blue, size: 20),
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
