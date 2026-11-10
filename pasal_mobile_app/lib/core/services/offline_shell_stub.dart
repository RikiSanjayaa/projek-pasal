import 'package:flutter/foundation.dart';

import 'offline_shell.dart';

final offlineShell = ValueNotifier<OfflineShellState>(
  const OfflineShellState(status: 'unsupported'),
);
void listenOfflineShell() {}
void stopListeningOfflineShell() {}
Future<void> refreshOfflineShell() async {}
Future<void> prepareOfflineShell() async {}
Future<String> installPwa() async => 'manual';
