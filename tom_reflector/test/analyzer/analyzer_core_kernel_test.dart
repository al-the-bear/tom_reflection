import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/analyzer_comparison.dart';

void main() {
  group('TomAnalyzer', () {
    group('core kernel analysis json', () {
      // Resolving a whole package and carrying it through JSON is a
      // half-minute of real work, and the default 30s deadline is met
      // only on an idle machine — which is not where a suite runs.
      test(
        'should contain all analyzer elements from core kernel',
        timeout: const Timeout(Duration(minutes: 5)),
        () async {
          final workspaceRoot = _findWorkspaceRoot();
          // Post-restructure, the core packages live under `tom_ai/core/…`
          // (they used to sit directly under the workspace root's `core/`).
          final rootPath = p.join(
            workspaceRoot,
            'tom_ai',
            'core',
            'tom_core_kernel',
          );
          final barrelPath = p.join(rootPath, 'lib', 'tom_core_kernel.dart');

          await compareAnalyzerToJson(
            rootPath: rootPath,
            barrelPath: barrelPath,
            packageName: 'tom_core_kernel',
          );
        },
      );
    });
  });
}

String _findWorkspaceRoot() {
  var current = Directory.current;
  while (true) {
    final candidate = File(p.join(current.path, 'tom_workspace.yaml'));
    if (candidate.existsSync()) {
      return current.path;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError(
        'Unable to locate workspace root containing tom_workspace.yaml',
      );
    }
    current = parent;
  }
}
