/// SCF11: `-n` on the reflector, analyzer and reflection-analyzer tools.
///
/// All three declared `dryRun: false` because nothing read `args.dryRun`, so
/// tom_build_base refused the flag. They now route every write through
/// [writeOrPreview], which under `-n` reports what it would create or update
/// and touches nothing.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_reflector/src/v2/analyzer_tool.dart';
import 'package:tom_reflector/src/v2/output_writer.dart';
import 'package:tom_reflector/src/v2/reflection_analyzer_tool.dart';
import 'package:tom_reflector/src/v2/reflector_tool.dart';

/// A scratch directory under the workspace's `ztmp/` — never the system temp.
Directory _scratch() {
  var dir = Directory.current;
  while (!Directory(p.join(dir.path, 'ztmp')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('no ztmp/ above ${Directory.current.path}');
    }
    dir = parent;
  }
  return Directory(
    p.join(dir.path, 'ztmp', 'scf11_${DateTime.now().microsecondsSinceEpoch}'),
  )..createSync(recursive: true);
}

void main() {
  late Directory scratch;
  setUp(() => scratch = _scratch());
  tearDown(() {
    if (scratch.existsSync()) scratch.deleteSync(recursive: true);
  });

  group('writeOrPreview under -n', () {
    test('F-SCF11-1: a missing output would be created, and is not '
        '[2026-09-29] (PASS)', () async {
      final path = p.join(scratch.path, 'doc', 'out.yaml');
      expect(await writeOrPreview(path, 'v1', dryRun: true), isTrue);
      expect(File(path).existsSync(), isFalse);
      expect(Directory(p.dirname(path)).existsSync(), isFalse);
    });

    test('F-SCF11-2: a differing output would be updated, and is left '
        'untouched [2026-09-29] (PASS)', () async {
      final path = p.join(scratch.path, 'out.yaml');
      File(path).writeAsStringSync('v0');
      expect(await writeOrPreview(path, 'v1', dryRun: true), isTrue);
      expect(File(path).readAsStringSync(), 'v0');
    });

    test('F-SCF11-3: an identical output is reported unchanged '
        '[2026-09-29] (PASS)', () async {
      final path = p.join(scratch.path, 'out.yaml');
      File(path).writeAsStringSync('v1');
      expect(await writeOrPreview(path, 'v1', dryRun: true), isFalse);
    });
  });

  test('F-SCF11-4: without -n it writes, creating the directory '
      '[2026-09-29] (PASS)', () async {
    final path = p.join(scratch.path, 'doc', 'out.yaml');
    expect(await writeOrPreview(path, 'v1', dryRun: false), isTrue);
    expect(File(path).readAsStringSync(), 'v1');
  });

  test('F-SCF11-5: all three tools advertise -n, so it is no longer refused '
      '[2026-09-29] (PASS)', () {
    expect(reflectorTool.features.dryRun, isTrue);
    expect(analyzerTool.features.dryRun, isTrue);
    expect(reflectionAnalyzerTool.features.dryRun, isTrue);
  });
}
