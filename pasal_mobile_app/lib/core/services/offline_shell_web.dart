import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'offline_shell.dart';

@JS('cariPasalOffline')
external _OfflineBridge? get _bridge;

extension type _OfflineBridge(JSObject _) implements JSObject {
  external JSObject getState();
  external JSPromise<JSObject> refresh();
  external JSPromise<JSObject> prepare();
  external JSPromise<JSString> install();
}

final offlineShell = ValueNotifier<OfflineShellState>(
  const OfflineShellState(status: 'preparing'),
);
int _subscribers = 0;
JSFunction? _listener;

void _read() {
  final value = _bridge?.getState().dartify();
  offlineShell.value = value is Map
      ? OfflineShellState.fromMap(value)
      : const OfflineShellState(
          status: 'unsupported',
          error: 'File aplikasi belum mendukung offline.',
        );
}

void listenOfflineShell() {
  if (_subscribers++ == 0) {
    _listener = ((web.Event _) => _read()).toJS;
    web.window.addEventListener('caripasal-offline-change', _listener);
  }
  _read();
  refreshOfflineShell();
}

void stopListeningOfflineShell() {
  if (_subscribers > 0 && --_subscribers == 0) {
    web.window.removeEventListener('caripasal-offline-change', _listener);
    _listener = null;
  }
}

Future<void> refreshOfflineShell() async {
  await _bridge?.refresh().toDart;
  _read();
}

Future<void> prepareOfflineShell() async {
  await _bridge?.prepare().toDart;
  _read();
}

Future<String> installPwa() async {
  final result = await _bridge?.install().toDart;
  _read();
  return result?.toDart ?? 'manual';
}
