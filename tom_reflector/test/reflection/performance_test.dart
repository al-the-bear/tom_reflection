/// Performance measurements for reflection code generation.
///
/// These tests MEASURE and REPORT; they do not gate on wall-clock duration.
///
/// SCD15 (scd15_aicx). Every timing here used to carry a threshold — eight of
/// them, from `lessThan(2000)` to `lessThan(60000)`. The small-fixture one
/// asserted `lessThan(5000)` and was measured at 8023 ms on an idle mbp, which
/// is what prompted this. Measured again on 2026-09-12, the same operation on
/// the same machine took:
///
///   2.0-2.5 s  run alone
///   3.5 s      run as part of the full suite
///   8.0 s      as recorded on 2026-09-03
///
/// Nothing about the analyzer changed between those numbers. The cost is
/// dominated by SDK summary loading and by how many other test isolates
/// `dart test` is running concurrently, so a fixed threshold cannot separate
/// "the analyzer got slower" from "the machine was busier" — it only reports
/// the second while appearing to report the first. Across a four-machine fleet
/// there is no constant that is both meaningful and stable.
///
/// A perpetually-red performance test is worse than no performance test: it
/// trains readers to discount red, and it costs the same triage on every
/// baseline. So the durations are emitted as `[PERF]` lines for comparison
/// across runs and machines, and the assertions that remain are the ones whose
/// outcome does not depend on ambient load — type counts, generated code size,
/// characters per type.
///
/// Raising a threshold to a number that passes today would reproduce the
/// original defect with a larger constant and no new information;
/// `performance_thresholds_guard_test.dart` fails if one comes back.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_reflector/src/reflection/generator/reflection_generator.dart';

/// Emits one greppable measurement line.
///
/// `[PERF] op=<name> ms=<duration>` matches the shape the flutter corpus uses
/// for its `[METRIC]` lines, so the same tooling habits apply: grep the run
/// log, compare across machines, and look at trends rather than at a single
/// number that a busy host can move by a factor of four.
void reportPerf(String op, Duration elapsed, [Map<String, Object?> extra =
    const {}]) {
  final tail = extra.entries.map((e) => ' ${e.key}=${e.value}').join();
  print('[PERF] op=$op ms=${elapsed.inMilliseconds}$tail');
}

void main() {
  group('ReflectionGenerator - Performance Tests', () {
    // Location of the large sample project - use absolute path
    // The test runs from tom_analyzer directory, so we navigate from workspace root
    final workspaceRoot = p.normalize(p.join(
      Directory.current.path,
      '..',
      '..',
      '..',
    ));
    final uamServerPath = p.join(workspaceRoot, 'uam', 'tom_uam_server');
    final aaServerStartPath =
        p.join(uamServerPath, 'bin', 'aa_server_start.dart');

    // Check if the UAM server project exists
    final uamServerExists = File(aaServerStartPath).existsSync();

    group('analysis performance', () {
      test('analyzes small fixture in reasonable time', () async {
        final fixturesPath = p.join(
          Directory.current.path,
          'test',
          'reflection',
          'fixtures',
          'sample_models.dart',
        );

        final stopwatch = Stopwatch()..start();

        final generator = ReflectionGenerator.fromMap({
          'entry_points': [fixturesPath],
        });
        final result = await generator.analyze();

        stopwatch.stop();

        // Load-independent: the analyzer either found the fixture's types or
        // it did not, and that answer is the same on any machine.
        expect(result.typeCount, greaterThan(0));

        reportPerf('analysis.small_fixture', stopwatch.elapsed, {
          'types': result.typeCount,
          'globalMembers': result.globalMemberCount,
        });
      });

      test('analysis time scales reasonably with type count', () async {
        final fixturesPath = p.join(
          Directory.current.path,
          'test',
          'reflection',
          'fixtures',
          'sample_models.dart',
        );

        // Run multiple analyses to get average
        final times = <int>[];
        for (var i = 0; i < 3; i++) {
          final stopwatch = Stopwatch()..start();

          final generator = ReflectionGenerator.fromMap({
            'entry_points': [fixturesPath],
          });
          await generator.analyze();

          stopwatch.stop();
          times.add(stopwatch.elapsedMilliseconds);
        }

        final avgTime = times.reduce((a, b) => a + b) / times.length;

        // The old assertion here was `times.last <= times.first + 1000`, meant
        // to show warm-up making later runs faster. The 1000 ms slack is an
        // absolute constant on a difference whose spread under concurrent test
        // isolates comfortably exceeds it, so it measured load like the rest.
        // Reported instead: first, last and mean are what a reader needs to see
        // whether warm-up still helps.
        reportPerf('analysis.repeat_x3', Duration(milliseconds: avgTime.round()), {
          'firstMs': times.first,
          'lastMs': times.last,
          'runs': times.length,
        });
      });
    },
        skip: !File(p.join(Directory.current.path, 'test', 'reflection',
                'fixtures', 'sample_models.dart'))
            .existsSync());

    group('code generation performance', () {
      test('generates code in reasonable time for small fixture', () async {
        final fixturesPath = p.join(
          Directory.current.path,
          'test',
          'reflection',
          'fixtures',
          'sample_models.dart',
        );

        final generator = ReflectionGenerator.fromMap({
          'entry_points': [fixturesPath],
        });

        // Measure analysis + generation separately
        final analysisWatch = Stopwatch()..start();
        await generator.analyze();
        analysisWatch.stop();

        final generationWatch = Stopwatch()..start();
        final code = await generator.generate();
        generationWatch.stop();

        // Load-independent: the generator produced substantial output or it
        // did not.
        expect(code.length, greaterThan(1000));

        reportPerf('analysis.before_generate', analysisWatch.elapsed);
        reportPerf('generate.small_fixture', generationWatch.elapsed, {
          'codeChars': code.length,
        });
      });

      test('generated code size is proportional to type count', () async {
        final fixturesPath = p.join(
          Directory.current.path,
          'test',
          'reflection',
          'fixtures',
          'sample_models.dart',
        );

        final generator = ReflectionGenerator.fromMap({
          'entry_points': [fixturesPath],
        });

        final result = await generator.analyze();
        final code = await generator.generate();

        // Kept as a real assertion: this is a size ratio, not a duration. It
        // is deterministic for a given fixture and generator, so it says
        // something about the code on every machine equally.
        final charsPerType = code.length / (result.typeCount + 1);
        print('Characters per type: ${charsPerType.toStringAsFixed(0)}');

        expect(charsPerType, lessThan(50000),
            reason: 'Generated code per type should be reasonable');
      });
    });

    group(
      'large codebase performance (UAM Server)',
      () {
        test('analyzes aa_server_start.dart entry point', () async {
          final stopwatch = Stopwatch()..start();

          final generator = ReflectionGenerator.fromMap({
            'entry_points': [aaServerStartPath],
          });
          final result = await generator.analyze();

          stopwatch.stop();

          reportPerf('analysis.uam_server', stopwatch.elapsed, {
            'classes': result.classes.length,
            'enums': result.enums.length,
            'mixins': result.mixins.length,
            'extensions': result.extensions.length,
            'globalFunctions': result.globalFunctions.length,
            'types': result.typeCount,
          });

          // Should discover a reasonable number of types
          expect(result.typeCount, greaterThan(0),
              reason: 'Should discover types from UAM server');
        });

        test('generates code for aa_server_start.dart', () async {
          final generator = ReflectionGenerator.fromMap({
            'entry_points': [aaServerStartPath],
          });

          final analysisWatch = Stopwatch()..start();
          await generator.analyze();
          analysisWatch.stop();

          final generationWatch = Stopwatch()..start();
          final code = await generator.generate();
          generationWatch.stop();

          reportPerf('analysis.uam_server.before_generate', analysisWatch.elapsed);
          reportPerf('generate.uam_server', generationWatch.elapsed, {
            'codeChars': code.length,
          });

          // Generated code should be substantial for a real project
          expect(code.length, greaterThan(10000));
        });

        test('memory usage is reasonable', () async {
          // Force GC before measurement
          // (Note: Dart doesn't expose direct memory APIs in tests,
          // but we can ensure no out-of-memory errors occur)

          final generator = ReflectionGenerator.fromMap({
            'entry_points': [aaServerStartPath],
          });

          // Should complete without memory issues
          final result = await generator.analyze();
          final code = await generator.generate();

          expect(result, isNotNull);
          expect(code, isNotEmpty);
        });
      },
      skip: !uamServerExists
          ? 'UAM Server project not found at $aaServerStartPath'
          : null,
    );

    group('generator efficiency', () {
      test('reusing generator is efficient', () async {
        final fixturesPath = p.join(
          Directory.current.path,
          'test',
          'reflection',
          'fixtures',
          'sample_models.dart',
        );

        final generator = ReflectionGenerator.fromMap({
          'entry_points': [fixturesPath],
        });

        // First run
        final watch1 = Stopwatch()..start();
        await generator.generate();
        watch1.stop();

        // Second run (reusing generator)
        final watch2 = Stopwatch()..start();
        await generator.generate();
        watch2.stop();

        // The interesting property here is the RATIO — reuse should make the
        // second generation dramatically cheaper — but a ratio assertion needs
        // a floor to avoid dividing by a sub-millisecond first run, and that
        // floor is another constant chosen on one machine. Reported.
        reportPerf('generate.first', watch1.elapsed);
        reportPerf('generate.reused', watch2.elapsed);
      });
    });
  });
}
