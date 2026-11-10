import 'package:material_ui/material_ui.dart';

import '../../core/config/app_colors.dart';
import '../../core/services/auth_service.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

/// Screen shown when user's account has expired
/// User must contact admin to re-provision their account
class LockScreen extends StatefulWidget {
  /// True bila akses offline 30 hari habis (akun sendiri belum tentu
  /// kedaluwarsa). Sesi dapat diperbarui lewat koneksi internet.
  final bool offlineLeaseExpired;

  const LockScreen({super.key, this.offlineLeaseExpired = false});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _refreshing = false;
  String? _refreshError;

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    final result = await authService.restoreSession();
    if (!mounted) return;
    if (result == ExpiryCheckResult.valid) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplashScreen()),
      );
      return;
    }
    // Bila sesi dicabut, AuthWrapper sudah mengarahkan ke layar login.
    setState(() {
      _refreshing = false;
      _refreshError =
          authService.isLoggedIn || result == ExpiryCheckResult.noData
          ? null
          : 'Tidak dapat memperbarui sesi. Periksa koneksi internet Anda.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final leaseExpired = widget.offlineLeaseExpired;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scaffold(isDark),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Lock icon
                      Container(
                        height: 140,
                        width: 140,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(
                            alpha: isDark ? 0.1 : 0.05,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border(isDark)),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          size: 60,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Title
                      Text(
                        leaseExpired
                            ? "Sesi Offline Berakhir"
                            : "Akun Kadaluarsa",
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
                        leaseExpired
                            ? "Akses offline Anda telah melewati batas 30 hari.\nHubungkan perangkat ke internet untuk memperbarui sesi."
                            : "Masa aktif akun Anda telah berakhir.\nHubungi administrator untuk memperpanjang.",
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary(isDark),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      // Info card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.card(isDark),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border(isDark)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.info.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline,
                                    color: AppColors.info,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    "Apa yang harus dilakukan?",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary(isDark),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (leaseExpired) ...[
                              _buildStep(
                                "1",
                                "Sambungkan perangkat ke internet",
                                isDark,
                              ),
                              const SizedBox(height: 12),
                              _buildStep(
                                "2",
                                "Tekan Perbarui Sesi untuk memverifikasi akun",
                                isDark,
                              ),
                            ] else ...[
                              _buildStep(
                                "1",
                                "Hubungi administrator kampus Anda",
                                isDark,
                              ),
                              const SizedBox(height: 12),
                              _buildStep(
                                "2",
                                "Minta perpanjangan masa aktif akun",
                                isDark,
                              ),
                              const SizedBox(height: 12),
                              _buildStep(
                                "3",
                                "Login kembali setelah akun diperpanjang",
                                isDark,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),

                      if (_refreshError != null) ...[
                        Text(
                          _refreshError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (leaseExpired) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _refreshing ? null : _refresh,
                            icon: _refreshing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                            label: const Text(
                              "Perbarui Sesi",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Logout button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await authService.logout();
                            if (context.mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text(
                            "Logout",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
