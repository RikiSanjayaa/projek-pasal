export 'offline_shell_stub.dart'
    if (dart.library.js_interop) 'offline_shell_web.dart';

class OfflineShellState {
  const OfflineShellState({
    required this.status,
    this.storagePersistent = false,
    this.updateAvailable = false,
    this.error,
    this.installStatus = 'manual',
  });

  final String status;
  final bool storagePersistent;
  final bool updateAvailable;
  final String? error;
  final String installStatus;

  factory OfflineShellState.fromMap(Map<Object?, Object?> value) =>
      OfflineShellState(
        status: value['status'] as String? ?? 'unsupported',
        storagePersistent: value['storagePersistent'] == true,
        updateAvailable: value['updateAvailable'] == true,
        error: value['error'] as String?,
        installStatus: value['installStatus'] as String? ?? 'manual',
      );
}
