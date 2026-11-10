import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/app_colors.dart';
import '../../core/config/app_theme.dart';
import '../../core/config/theme_controller.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_info_service.dart';
import '../../core/services/sync_manager.dart';
import '../../core/services/sync_progress.dart';
import '../../core/services/tutorial_service.dart';
import '../../core/utils/date_format_id.dart';
import '../screens/login_screen.dart';
import '../utils/responsive_layout.dart';

/// Lets routed screens distinguish the persistent shell from standalone readers.
class NavigationSettingsScope extends InheritedWidget {
  const NavigationSettingsScope({super.key, required super.child});

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavigationSettingsScope>() !=
      null;

  @override
  bool updateShouldNotify(NavigationSettingsScope oldWidget) => false;
}

/// Compact screens and standalone routes have one settings entry; shell panels do not.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= ResponsiveLayout.medium &&
        NavigationSettingsScope.contains(context)) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: 'Pengaturan',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => openSettingsDrawer(context),
    );
  }
}

bool _settingsOpen = false;

Future<void> openSettingsDrawer(BuildContext context) async {
  if (_settingsOpen) return;
  _settingsOpen = true;
  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup pengaturan',
      pageBuilder: (context, _, _) => const Align(
        alignment: Alignment.centerRight,
        child: SettingsDrawer(),
      ),
    );
  } finally {
    _settingsOpen = false;
  }
}

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context) => Drawer(
    width: (MediaQuery.sizeOf(context).width * .9).clamp(0.0, 400.0),
    // This drawer is positioned explicitly, outside Scaffold.endDrawer.
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(
        left: Radius.circular(AppTheme.radiusSheet),
      ),
    ),
    backgroundColor: AppColors.card(
      Theme.of(context).brightness == Brightness.dark,
    ),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pengaturan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup pengaturan',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: SettingsControls(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shared controls for the mobile panel and the persistent desktop sidebar.
class SettingsControls extends StatefulWidget {
  const SettingsControls({
    super.key,
    this.sidebar = false,
    this.collapsed = false,
    this.accountOnly = false,
  });

  final bool sidebar;
  final bool collapsed;
  final bool accountOnly;

  @override
  State<SettingsControls> createState() => _SettingsControlsState();
}

class _SettingsControlsState extends State<SettingsControls> {
  bool _success = false;

  List<String> _accessLines() {
    final lines = <String>[];
    final expires = authService.accountExpiresAt.value;
    if (authService.accountType.value == AccountType.admin) {
      lines.add('Admin • Tanpa masa kedaluwarsa akun');
    } else if (authService.accountType.value == AccountType.mobile) {
      lines.add(
        expires == null
            ? 'Akun tanpa batas masa aktif'
            : 'Akun berlaku hingga ${DateFormatId.short(expires)}',
      );
    }
    final lease = authService.offlineAccessUntil.value;
    if (lease != null)
      lines.add('Akses offline hingga ${DateFormatId.short(lease)}');
    return lines;
  }

  Future<void> _accountDialog() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Profil'),
      content: const SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: SettingsControls(accountOnly: true),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );

  Future<void> _passwordDialog() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ganti Password'),
      content: const Text(
        'Reset password email belum tersedia di backend Laravel lokal. Hubungi admin untuk dibuatkan password awal baru.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );

  Future<void> _logout() => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Keluar dari Akun?'),
      content: const Text('Anda perlu login kembali untuk mengakses aplikasi.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            final navigator = Navigator.of(dialogContext);
            await TutorialService.resetAll();
            await authService.logout();
            if (!dialogContext.mounted) return;
            navigator.pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              (_) => false,
            );
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Keluar'),
        ),
      ],
    ),
  );

  Future<void> _checkUpdate() async {
    if (syncManager.state.value == SyncState.checking ||
        syncManager.state.value == SyncState.syncing)
      return;
    if (syncManager.updateAvailable.value) {
      await syncManager.performSync();
    } else {
      final hasUpdate = await syncManager.checkForUpdates();
      if (!mounted) return;
      setState(
        () =>
            _success = !hasUpdate && syncManager.state.value == SyncState.idle,
      );
    }
  }

  Widget _themes() => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeController,
    builder: (context, mode, _) {
      const options = [
        (ThemeMode.system, Icons.brightness_auto_outlined, 'Sistem'),
        (ThemeMode.light, Icons.light_mode_outlined, 'Terang'),
        (ThemeMode.dark, Icons.dark_mode_outlined, 'Gelap'),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tema',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final option in options)
                Expanded(
                  child: Tooltip(
                    message: option.$3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: TextButton(
                        onPressed: () => themeController.setTheme(option.$1),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: mode == option.$1
                              ? AppColors.primary.withValues(alpha: .1)
                              : null,
                          foregroundColor: mode == option.$1
                              ? AppColors.primary
                              : AppColors.textSecondary(
                                  Theme.of(context).brightness ==
                                      Brightness.dark,
                                ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(option.$2, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              option.$3,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );

  Widget _sync() => ValueListenableBuilder<SyncState>(
    valueListenable: syncManager.state,
    builder: (context, state, _) => ValueListenableBuilder<bool>(
      valueListenable: syncManager.updateAvailable,
      builder: (context, available, _) => ValueListenableBuilder<SyncProgress?>(
        valueListenable: syncManager.progress,
        builder: (context, progress, _) {
          final busy =
              state == SyncState.checking || state == SyncState.syncing;
          final label = switch (state) {
            SyncState.checking => 'Memeriksa...',
            SyncState.syncing => 'Sinkronisasi...',
            _ =>
              available
                  ? 'Update Tersedia'
                  : (_success ? 'Data Sudah Terbaru' : 'Periksa Update'),
          };
          final icon = busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  available ? Icons.system_update_outlined : Icons.sync_rounded,
                  size: 20,
                );
          if (widget.collapsed) {
            return IconButton(
              tooltip: label,
              onPressed: busy ? null : _checkUpdate,
              icon: icon,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: icon,
                title: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  state == SyncState.syncing
                      ? (progress?.currentOperation ?? 'Memproses...')
                      : 'Data: ${syncManager.dataUpdatedText}\nSync: ${syncManager.lastSyncText}',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: busy ? null : _checkUpdate,
              ),
              if (state == SyncState.syncing) ...[
                LinearProgressIndicator(value: progress?.progress),
                TextButton.icon(
                  onPressed: syncManager.cancelSync,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Batalkan'),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );

  Widget _account() => ValueListenableBuilder<String?>(
    valueListenable: authService.userName,
    builder: (context, name, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name ?? 'Pengguna',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          authService.currentUserEmail ?? '',
          style: const TextStyle(fontSize: 12),
        ),
        for (final line in _accessLines())
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(line, style: const TextStyle(fontSize: 11)),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: _passwordDialog,
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('Ganti Password'),
            ),
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Keluar'),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.accountOnly) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_account(), const Divider(height: 32), _themes()],
      );
    }
    return Column(
      crossAxisAlignment: widget.collapsed
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.sidebar) ...[
          _account(),
          const Divider(height: 32),
          _themes(),
          const SizedBox(height: 8),
        ],
        _sync(),
        if (widget.sidebar) ...[
          const Divider(height: 24),
          ValueListenableBuilder<String?>(
            valueListenable: authService.userName,
            builder: (context, name, _) => widget.collapsed
                ? IconButton(
                    tooltip: 'Profil',
                    onPressed: _accountDialog,
                    icon: const Icon(Icons.account_circle_outlined),
                  )
                : ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.account_circle_outlined),
                    title: Text(
                      name ?? 'Pengguna',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Profil',
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: _accountDialog,
                  ),
          ),
        ],
        if (!kIsWeb && !widget.sidebar) ...[
          const Divider(height: 32),
          FutureBuilder<StorageInfo>(
            future: storageInfoService.getStorageInfo(),
            builder: (context, snapshot) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storage_outlined),
              title: Text(snapshot.data?.summary ?? 'Memuat penyimpanan...'),
              subtitle: Text(snapshot.data?.formattedSize ?? ''),
            ),
          ),
        ],
      ],
    );
  }
}
