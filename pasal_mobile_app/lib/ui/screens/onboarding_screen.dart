import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/sync_manager.dart';
import '../../core/services/sync_progress.dart';
import '../widgets/app_notification.dart';
import '../widgets/main_navigation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isDownloading = false;

  final List<Map<String, dynamic>> _pages = [
    {
      "title": "Selamat Datang",
      "desc":
          "Aplikasi Kitab Undang-Undang Hukum (KUHP, ITE, dll) dalam genggaman Anda.",
      "icon": Icons.menu_book_rounded,
      "color": AppColors.primary,
    },
    {
      "title": "Pencarian Cepat",
      "desc":
          "Cari pasal berdasarkan nomor atau kata kunci dengan fitur highlight pintar.",
      "icon": Icons.search_rounded,
      "color": AppColors.success,
    },
    {
      "title": "Siapkan Data Offline",
      "desc":
          "Unduh data sekarang agar aplikasi bisa digunakan tanpa internet.",
      "icon": Icons.cloud_download_rounded,
      "color": AppColors.warning,
    },
  ];

  Future<void> _startDownload() async {
    setState(() => _isDownloading = true);

    final result = await syncManager.performSync();

    if (!mounted) return;

    if (result.success) {
      final dbSize = await getDatabaseSizeFormatted();
      if (!mounted) return;

      _showCompletionDialog(dbSize);
    } else if (syncManager.progress.value?.phase == SyncPhase.cancelled) {
      setState(() => _isDownloading = false);
      AppNotification.show(
        context,
        "Unduhan dibatalkan",
        color: AppColors.warning,
        icon: Icons.cancel,
      );
    } else {
      setState(() => _isDownloading = false);
      AppNotification.show(
        context,
        result.message,
        color: AppColors.error,
        icon: Icons.error_outline,
      );
    }
  }

  void _showCompletionDialog(String dbSize) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = syncManager.progress.value;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.card(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Unduhan Selesai!",
                    style: TextStyle(
                      color: AppColors.textPrimary(isDark),
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2, 
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  Icons.article,
                  "${progress?.totalPasal ?? 0} pasal",
                  isDark,
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  Icons.folder,
                  "${progress?.totalUU ?? 0} undang-undang",
                  isDark,
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  Icons.cloud_download,
                  progress?.downloadedBytesFormatted ?? "0 B",
                  isDark,
                ),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.storage, "Database: $dbSize", isDark),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MainNavigation(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Mulai Menggunakan Aplikasi",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.inputFill(isDark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.card(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              "Batalkan Unduhan?",
              style: TextStyle(
                color: AppColors.textPrimary(isDark),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              "Unduhan akan dihentikan dan Anda perlu mengulang dari awal. Yakin ingin membatalkan?",
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary(isDark),
                ),
                child: const Text("Lanjutkan Unduhan"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  syncManager.cancelSync();
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text("Ya, Batalkan"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppColors.scaffold(isDark);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  _isDownloading
                      ? _buildDownloadingView(isDark)
                      : _buildOnboardingPages(isDark),
            ),
            if (!_isDownloading) _buildBottomSection(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPages(bool isDark) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (idx) => setState(() => _currentPage = idx),
      itemCount: _pages.length,
      itemBuilder: (context, index) {
        final page = _pages[index];
        final color = page['color'] as Color;

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container with gradient
              Container(
                height: 160,
                width: 160,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.1 : 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: isDark ? 0.5 : 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(page['icon'] as IconData, size: 70, color: color),
              ),
              const SizedBox(height: 48),

              // Title
              Text(
                page['title']!,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                page['desc']!,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary(isDark),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDownloadingView(bool isDark) {
    return ValueListenableBuilder<SyncProgress?>(
      valueListenable: syncManager.progress,
      builder: (context, progress, child) {
        final isComplete = progress?.phase == SyncPhase.complete;
        final isError = progress?.phase == SyncPhase.error;

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with status
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: (isError ? AppColors.error : AppColors.primary)
                      .withValues(alpha: isDark ? 0.1 : 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isError ? AppColors.error : AppColors.primary)
                        .withValues(alpha: isDark ? 0.5 : 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _getPhaseIcon(progress?.phase),
                  size: 50,
                  color: isError ? AppColors.error : AppColors.primary,
                ),
              ),
              const SizedBox(height: 40),

              // Title
              Text(
                isComplete ? "Unduhan Selesai!" : "Mengunduh Database Hukum",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Progress bar
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress?.progress ?? 0,
                    minHeight: 12,
                    backgroundColor:
                        isDark
                            ? Colors.grey[800]
                            : Colors.white, // Clean white for light mode
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isError ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Progress percentage and time estimate
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${progress?.progressPercent ?? 0}%",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (progress?.estimatedRemainingFormatted != null)
                    Text(
                      progress!.estimatedRemainingFormatted!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Current operation container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(isDark)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              isComplete
                                  ? Icon(
                                    Icons.check_circle,
                                    size: 20,
                                    color: AppColors.success,
                                  )
                                  : CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      AppColors.primary,
                                    ),
                                  ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            progress?.currentOperation ?? "Mempersiapkan...",
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (progress?.uuProgressText != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const SizedBox(width: 32),
                          Icon(
                            Icons.book,
                            size: 16,
                            color: AppColors.textSecondary(isDark),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            progress!.uuProgressText!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Download stats chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatChip(
                    Icons.cloud_download,
                    progress?.downloadedBytesFormatted ?? "0 B",
                    isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildStatChip(
                    Icons.article,
                    "${progress?.downloadedPasal ?? 0}/${progress?.totalPasal ?? '?'}",
                    isDark,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Cancel button
              if (progress?.phase != SyncPhase.complete &&
                  progress?.phase != SyncPhase.cancelled)
                TextButton.icon(
                  onPressed: _confirmCancel,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text("Batalkan Unduhan"),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.5 : 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPhaseIcon(SyncPhase? phase) {
    switch (phase) {
      case SyncPhase.downloadingUU:
        return Icons.book;
      case SyncPhase.downloadingPasal:
        return Icons.article;
      case SyncPhase.downloadingLinks:
        return Icons.link;
      case SyncPhase.saving:
        return Icons.save;
      case SyncPhase.complete:
        return Icons.check_circle;
      case SyncPhase.error:
        return Icons.error;
      case SyncPhase.cancelled:
        return Icons.cancel;
      default:
        return Icons.cloud_download;
    }
  }

  Widget _buildBottomSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 28 : 8,
                decoration: BoxDecoration(
                  color:
                      _currentPage == index
                          ? AppColors.primary
                          : AppColors.border(isDark),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage < _pages.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                } else {
                  _startDownload();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentPage < _pages.length - 1
                        ? "Lanjut"
                        : "Mulai & Unduh",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _currentPage < _pages.length - 1
                        ? Icons.arrow_forward_rounded
                        : Icons.download_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
