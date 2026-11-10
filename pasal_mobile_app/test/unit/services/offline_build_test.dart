import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/build_web.dart';

void main() {
  test(
    'precache URLs address literal percent escapes and spaces on the server',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'caripasal-offline-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final files = {
        'index.html': '<script src="offline.js"></script><script src="flutter_bootstrap.js"></script>',
        'main.dart.js': 'application();',
        'flutter_bootstrap.js':
            'const build={"mainJsPath":"main.dart.js"};'
            "const config={canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href};",
        'offline.js': "const version='__CARIPASAL_VERSION__';",
        'sqlite3.wasm': 'sqlite',
        'drift_worker.dart.js': 'database',
        'canvaskit/canvaskit.js': 'renderer',
        'images/logo-ubg%20hitam.png': 'encoded filename',
        'images/logo putih.png': 'spaced filename',
      };
      for (final entry in files.entries) {
        final file = File('${directory.path}/${entry.key}');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(entry.value);
      }
      await prepareOfflineBuild(directory);
      final source = File('${directory.path}/caripasal-sw.js')
          .readAsStringSync();
      final manifest = jsonDecode(
        RegExp(
          r'^const BUILD = (.*);$',
          multiLine: true,
        ).firstMatch(source)!.group(1)!,
      ) as Map<String, dynamic>;
      final paths = (manifest['assets'] as Map<String, dynamic>).keys;
      // A web server decodes a URL once. A literal percent in a filename must survive it.
      final resolved = paths
          .map((url) => Uri.parse(url).pathSegments.join('/'))
          .toSet();
      expect(
        resolved,
        containsAll(['images/logo-ubg%20hitam.png', 'images/logo putih.png']),
      );
      expect(paths, contains('images/logo-ubg%2520hitam.png'));
      expect(paths, contains('images/logo%20putih.png'));
    },
  );
}
