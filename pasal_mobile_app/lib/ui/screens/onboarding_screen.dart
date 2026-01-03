import 'package:flutter/material.dart';
import '../../core/services/sync_manager.dart';
import '../../core/services/sync_progress.dart';
import 'main_navigation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isDownloading = false;

  final List<Map<String, String>> _pages = [
    {
      "title": "Selamat Datang",
      "desc": "Aplikasi Kitab Undang-Undang Hukum (KUHP, ITE, dll) dalam genggaman Anda.",
      "icon": "assets/images/logo.png" 
    },
    {
      "title": "Pencarian Cepat",
      "desc": "Cari pasal berdasarkan nomor atau kata kunci dengan fitur highlight pintar.",
      "icon": "assets/images/logo.png"
    },
    {
      "title": "Siapkan Data Offline",
      "desc": "Unduh data sekarang agar aplikasi bisa digunakan tanpa internet.",
      "icon": "assets/images/logo.png"
    },
  ];

  Future<void> _startDownload() async {
    setState(() => _isDownloading = true);
    
    final result = await syncManager.performSync();
    
    if (!mounted) return;

    if (result.success) {
      // Show completion info before navigating
      final dbSize = await getDatabaseSizeFormatted();
      if (!mounted) return;
      
      _showCompletionDialog(dbSize);
    } else if (syncManager.progress.value?.phase == SyncPhase.cancelled) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unduhan dibatalkan"),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCompletionDialog(String dbSize) {
    final progress = syncManager.progress.value;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
            ),
            const SizedBox(width: 12),
            const Text("Unduhan Selesai!"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.article, "${progress?.totalPasal ?? 0} pasal"),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.folder, "${progress?.totalUU ?? 0} undang-undang"),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.cloud_download, progress?.downloadedBytesFormatted ?? "0 B"),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.storage, "Database: $dbSize"),
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
                  MaterialPageRoute(builder: (context) => const MainNavigation()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Mulai Menggunakan Aplikasi"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  void _confirmCancel() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Batalkan Unduhan?"),
        content: const Text(
          "Unduhan akan dihentikan dan Anda perlu mengulang dari awal. Yakin ingin membatalkan?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Lanjutkan Unduhan"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              syncManager.cancelSync();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Ya, Batalkan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isDownloading 
                  ? _buildDownloadingView()
                  : _buildOnboardingPages(),
            ),
            if (!_isDownloading) _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPages() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (idx) => setState(() => _currentPage = idx),
      itemCount: _pages.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 200, width: 200,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle
                ),
                child: Icon(Icons.menu_book_rounded, size: 80, color: Colors.blue),
              ),
              const SizedBox(height: 40),
              Text(
                _pages[index]['title']!,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _pages[index]['desc']!,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDownloadingView() {
    return ValueListenableBuilder<SyncProgress?>(
      valueListenable: syncManager.progress,
      builder: (context, progress, child) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with pulse animation
              Container(
                height: 120, width: 120,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getPhaseIcon(progress?.phase),
                  size: 56,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 40),
              
              // Title
              Text(
                progress?.phase == SyncPhase.complete 
                    ? "Unduhan Selesai!"
                    : "Mengunduh Database Hukum",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress?.progress ?? 0,
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress?.phase == SyncPhase.error 
                        ? Colors.red 
                        : Colors.blue,
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
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (progress?.estimatedRemainingFormatted != null)
                    Text(
                      progress!.estimatedRemainingFormatted!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Current operation with UU progress
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress?.phase == SyncPhase.complete ? 1 : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            progress?.currentOperation ?? "Mempersiapkan...",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    if (progress?.uuProgressText != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 32),
                          Icon(Icons.book, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            progress!.uuProgressText!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Download stats
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatChip(
                    Icons.cloud_download,
                    progress?.downloadedBytesFormatted ?? "0 B",
                  ),
                  const SizedBox(width: 16),
                  _buildStatChip(
                    Icons.article,
                    "${progress?.downloadedPasal ?? 0}/${progress?.totalPasal ?? '?'} pasal",
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
                    foregroundColor: Colors.red.shade400,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
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

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: _currentPage == index ? 24 : 8,
              decoration: BoxDecoration(
                color: _currentPage == index ? Colors.blue : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            )),
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage < _pages.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300), 
                    curve: Curves.ease,
                  );
                } else {
                  _startDownload();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentPage < _pages.length - 1 ? "Lanjut" : "Mulai & Unduh",
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
