import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Run from pasal_mobile_app: dart run tool/build_web.dart [flutter build web args].
Future<void> main(List<String> args) async {
  if (args.contains('--help')) {
    stdout.writeln(
      'dart run tool/build_web.dart [flutter build web arguments]',
    );
    return;
  }
  final build = await Process.start(
    Platform.isWindows ? 'flutter.bat' : 'flutter',
    ['build', 'web', ...args, '--no-web-resources-cdn'],
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  final result = await build.exitCode;
  if (result != 0) {
    exitCode = result;
    return;
  }
  // Use Flutter's output argument when explicitly supplied.
  var output = 'build/web';
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--output=')) output = args[i].substring(9);
    if ((args[i] == '--output' || args[i] == '-o') && i + 1 < args.length)
      output = args[++i];
  }
  await prepareOfflineBuild(Directory(output));
}

Future<void> prepareOfflineBuild(Directory directory) async {
  final root = directory.absolute;
  File file(String path) => File('${root.path}/$path');
  final template = File('tool/offline_worker.js').readAsStringSync();
  // The cleanup-only worker is never shipped or registered by this application.
  final legacy = file('flutter_service_worker.js');
  if (legacy.existsSync()) legacy.deleteSync();
  final generated = ['caripasal-sw.js', 'offline-build.json'];
  for (final name in generated) {
    if (file(name).existsSync()) file(name).deleteSync();
  }
  final paths =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .map(
            (f) => f.path.substring(root.path.length + 1).replaceAll('\\', '/'),
          )
          .where((path) => !path.endsWith('.map'))
          .toList()
        ..sort();
  for (final required in [
    'index.html',
    'main.dart.js',
    'flutter_bootstrap.js',
    'offline.js',
    'sqlite3.wasm',
    'drift_worker.dart.js',
    'canvaskit/canvaskit.js',
  ]) {
    if (!paths.contains(required))
      throw StateError('Missing offline runtime asset: $required');
  }
  String assetPath(String path) =>
      path.split('/').map(Uri.encodeComponent).join('/');
  final seed = StringBuffer(template);
  for (final path in paths) {
    seed.write(
      '${assetPath(path)}:${sha256.convert(file(path).readAsBytesSync())}\n',
    );
  }
  final version = sha256.convert(utf8.encode(seed.toString())).toString();
  final manager = file('offline.js');
  manager.writeAsStringSync(
    manager.readAsStringSync().replaceAll('__CARIPASAL_VERSION__', version),
  );
  final index = file('index.html');
  index.writeAsStringSync(
    index
        .readAsStringSync()
        .replaceAll(
          'src="flutter_bootstrap.js"',
          'src="flutter_bootstrap.js?v=$version"',
        )
        .replaceAll('src="offline.js"', 'src="offline.js?v=$version"'),
  );
  final bootstrap = file('flutter_bootstrap.js');
  final bootstrapText = bootstrap.readAsStringSync();
  if (!bootstrapText.contains('"mainJsPath":"main.dart.js"') ||
      !bootstrapText.contains("canvasKitBaseUrl: new URL('canvaskit/'")) {
    throw StateError('Use the tracked web/flutter_bootstrap.js template');
  }
  bootstrap.writeAsStringSync(
    bootstrapText.replaceAll(
      '"mainJsPath":"main.dart.js"',
      '"mainJsPath":"main.dart.js?v=$version"',
    ),
  );
  final assets = <String, String>{};
  var bytes = 0;
  for (final path in paths) {
    final content = file(path).readAsBytesSync();
    assets[assetPath(path)] = sha256.convert(content).toString();
    bytes += content.length;
  }
  final manifest = {'version': version, 'assets': assets};
  file('caripasal-sw.js').writeAsStringSync(
    template.replaceFirst('__CARIPASAL_MANIFEST__', jsonEncode(manifest)),
  );
  file('offline-build.json').writeAsStringSync(
    jsonEncode({
      'version': version,
      'assetCount': assets.length,
      'bytes': bytes,
    }),
  );
  stdout.writeln(
    'Offline shell $version: ${assets.length} files, $bytes bytes',
  );
}
