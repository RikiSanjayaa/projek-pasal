import 'dart:async';

import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/data_service.dart';
import '../../core/services/offline_shell.dart';
import '../../core/services/sync_manager.dart';
import '../../core/utils/date_format_id.dart';

class OfflineStatusPanel extends StatefulWidget {
  const OfflineStatusPanel({super.key});

  @override
  State<OfflineStatusPanel> createState() => _OfflineStatusPanelState();
}

class _OfflineStatusPanelState extends State<OfflineStatusPanel>
    with WidgetsBindingObserver {
  bool _hasData = false;
  int _query = 0;
  Timer? _deadlineTimer;
  late final Listenable _signals;

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    return '${DateFormatId.short(local)} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _signals = Listenable.merge([
      offlineShell,
      authService.state,
      authService.offlineAccessUntil,
      authService.accountExpiresAt,
      syncManager.state,
    ]);
    WidgetsBinding.instance.addObserver(this);
    syncManager.state.addListener(_loadData);
    authService.offlineAccessUntil.addListener(_scheduleDeadline);
    authService.accountExpiresAt.addListener(_scheduleDeadline);
    listenOfflineShell();
    _loadData();
    _scheduleDeadline();
  }

  DateTime? get _deadline {
    final lease = authService.offlineAccessUntil.value;
    final expires = authService.accountExpiresAt.value;
    if (lease == null) return null;
    return expires != null && expires.isBefore(lease) ? expires : lease;
  }

  void _scheduleDeadline() {
    _deadlineTimer?.cancel();
    final duration = _deadline?.difference(clock.now());
    if (duration != null && duration > Duration.zero) {
      _deadlineTimer = Timer(
        duration > const Duration(days: 1) ? const Duration(days: 1) : duration,
        () {
          if (mounted) {
            setState(() {});
            _scheduleDeadline();
          }
        },
      );
    }
  }

  Future<void> _loadData() async {
    final query = ++_query;
    bool exists;
    try {
      exists =
          syncManager.lastSyncTime != null && await DataService.hasLocalPasal();
    } catch (_) {
      exists = false;
    }
    if (mounted && query == _query) setState(() => _hasData = exists);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshOfflineShell();
      _loadData();
      _scheduleDeadline();
    }
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    syncManager.state.removeListener(_loadData);
    authService.offlineAccessUntil.removeListener(_scheduleDeadline);
    authService.accountExpiresAt.removeListener(_scheduleDeadline);
    stopListeningOfflineShell();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _install() async {
    final result = await installPwa();
    if (!mounted || result != 'manual') return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pasang CariPasal'),
        content: const SingleChildScrollView(
          child: Text(
            'Android/Chrome dan desktop: buka menu browser, lalu pilih Instal aplikasi atau Tambahkan ke layar utama. '
            'Jika pilihan belum muncul, browser belum menyediakan instalasi untuk halaman ini.\n\n'
            'iPhone/iPad: buka di Safari → Bagikan → Tambahkan ke Layar Utama.\n\n'
            'Setelah memasang, buka aplikasi dari ikonnya. Selesaikan login, sinkronisasi data, dan persiapan offline '
            'di aplikasi terpasang sebelum memutus internet. Pemasangan saja belum berarti siap offline.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _signals,
    builder: (context, _) {
      final shell = offlineShell.value;
      final deadline = _deadline;
      final accessValid =
          authService.state.value == AuthState.authenticated &&
          deadline != null &&
          deadline.isAfter(clock.now());
      final syncing = syncManager.state.value == SyncState.syncing;
      final dataReady = _hasData && !syncing;
      final ready = shell.status == 'ready' && dataReady && accessValid;
      final lastSync = syncManager.lastSyncTime;
      final dataDate = syncManager.dataUpdatedAt;
      final fileStatus = switch (shell.status) {
        'ready' => 'File aplikasi tersimpan',
        'preparing' => 'Menyiapkan file aplikasi...',
        'unsupported' => 'Browser tidak mendukung offline',
        _ => 'File aplikasi belum lengkap',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready
                    ? Icons.offline_pin_outlined
                    : Icons.offline_bolt_outlined,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ready ? 'Siap digunakan offline' : 'Belum siap offline',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(fileStatus, style: const TextStyle(fontSize: 12)),
          Text(
            syncing
                ? 'Data sedang disinkronkan'
                : dataReady
                ? 'Data hukum tersimpan di perangkat'
                : 'Sinkronkan data hukum hingga selesai saat online.',
            style: const TextStyle(fontSize: 12),
          ),
          if (lastSync != null)
            Text(
              'Sinkronisasi terakhir ${_dateTime(lastSync)}',
              style: const TextStyle(fontSize: 12),
            ),
          if (dataDate != null)
            Text(
              'Data diperbarui ${_dateTime(dataDate)}',
              style: const TextStyle(fontSize: 12),
            ),
          Text(
            deadline == null
                ? 'Login online diperlukan untuk akses offline.'
                : accessValid
                ? 'Akses offline hingga ${_dateTime(deadline)}'
                : 'Akses offline berakhir. Hubungkan internet untuk verifikasi akun.',
            style: const TextStyle(fontSize: 12),
          ),
          if (shell.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(shell.error!, style: const TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 8),
          Text(
            shell.storagePersistent
                ? 'Penyimpanan persisten diberikan browser. Menghapus data situs tetap menghapus data offline.'
                : 'Penyimpanan belum persisten. Browser dapat membersihkan file dan data saat ruang terbatas.',
            style: const TextStyle(fontSize: 12),
          ),
          if (shell.updateAvailable)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Versi baru siap. Tutup semua tab CariPasal dan aplikasi terpasang, lalu buka kembali. Data dan bookmark tetap tersimpan.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (shell.status != 'unsupported')
            TextButton.icon(
              onPressed: shell.status == 'preparing'
                  ? null
                  : prepareOfflineShell,
              icon: const Icon(Icons.download_for_offline_outlined, size: 18),
              label: const Text('Siapkan offline'),
            ),
          if (shell.installStatus == 'installed')
            const Text('Aplikasi terpasang', style: TextStyle(fontSize: 12))
          else
            TextButton.icon(
              onPressed: _install,
              icon: const Icon(Icons.install_mobile_outlined, size: 18),
              label: Text(
                shell.installStatus == 'available'
                    ? 'Pasang aplikasi'
                    : 'Cara pasang di layar utama',
              ),
            ),
        ],
      );
    },
  );
}
