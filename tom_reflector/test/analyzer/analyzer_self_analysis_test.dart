import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/analyzer_comparison.dart';

void main() {
  group('TomAnalyzer', () {
    group('self analysis json', () {
      // Resolving a whole package and carrying it through JSON is a
      // half-minute of real work, and the default 30s deadline is met
      // only on an idle machine — which is not where a suite runs.
      test(
        'should contain all analyzer elements from the package',
        timeout: const Timeout(Duration(minutes: 5)),
        () async {
          final rootPath = _findTomReflectorRoot();
          final barrelPath = p.join(rootPath, 'lib', 'tom_reflector.dart');

          await compareAnalyzerToJson(
            rootPath: rootPath,
            barrelPath: barrelPath,
            packageName: 'tom_reflector',
          );
        },
      );
    });
  });
}

String _findTomReflectorRoot() {
  var current = Directory.current;
  while (true) {
    final pubspec = File(p.join(current.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: tom_reflector')) {
      return current.path;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError('Unable to locate tom_reflector package root.');
    }
    current = parent;
  }
}
