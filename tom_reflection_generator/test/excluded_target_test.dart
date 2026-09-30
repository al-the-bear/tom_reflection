/// A generation target resolves even when the analysis options exclude it.
///
/// A workspace's shared `analysis_options.yaml` commonly excludes test
/// fixtures from linting (`**/test/**/fixtures/**`), and a reflection root is
/// often exactly such a fixture: `tom_core_server` roots its test mirror at
/// `test/fixtures/reflection_fixture.dart`. From analyzer 10.2 on, a file the
/// options exclude belongs to no analysis context when only the project root is
/// included, so resolving it threw "Unable to find the context" and the target
/// failed to generate — a failure that appeared with an analyzer upgrade and
/// no change to the project.
///
/// The fixture here sits under `test/fixtures/excluded_by_options/`, which this
/// package's own analysis options exclude for this test's sake.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_reflection_generator/tom_reflection_generator.dart';

void main() {
  final packageRoot = Directory.current.path;
  final fixture = p.join(
    packageRoot,
    'test',
    'fixtures',
    'excluded_by_options',
    'excluded_target_fixture.dart',
  );
  final generated = p.join(
    packageRoot,
    'test',
    'fixtures',
    'excluded_by_options',
    'excluded_target_fixture.reflection.dart',
  );

  tearDownAll(() {
    final file = File(generated);
    if (file.existsSync()) file.deleteSync();
  });

  for (final noCache in [true, false]) {
    test('an excluded target generates (${noCache ? 'no' : 'with'} summary '
        'cache)', () async {
      final result = await generateReflection(
        projectRoot: packageRoot,
        targets: [fixture],
        options: ReflectionGenerationOptions(noCache: noCache),
      );
      expect(
        result.failedCount,
        0,
        reason: 'the excluded target was not resolvable',
      );
      expect(result.processedCount, 1);
      expect(File(generated).readAsStringSync(), contains('Excluded'));
      // A cold summary cache analyzes every dependency first.
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
