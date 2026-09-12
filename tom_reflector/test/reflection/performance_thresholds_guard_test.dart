/// SCD15 (scd15_aicx): performance measurements must not gate on wall clock.
///
/// `performance_test.dart` carried eight duration thresholds. One of them,
/// `lessThan(5000)` over a small-fixture analysis, was measured at 8023 ms on
/// an idle machine — and at 2.0 s, 3.5 s and 8.0 s on the SAME machine
/// depending only on how many other test isolates were running. A constant
/// cannot separate a slower analyzer from a busier host, so the timings became
/// reported `[PERF]` lines and the assertions that remain are the
/// load-independent ones.
///
/// The obvious way to "fix" a red performance test is to raise its number
/// until it passes, which reproduces the defect with a larger constant and no
/// new information. This guard exists to make that fail loudly instead.
///
/// It lives in its own file rather than inside `performance_test.dart` on
/// purpose: a source-scanning guard that also matches its own source is a trap
/// that only springs once the file is committed, which is precisely how the
/// tracked-artifact guard in this package first went wrong.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// An `expect` comparing something duration-shaped against a numeric literal.
///
/// Matching on the identifier is the only handle available — nothing in the
/// source says a `List<int>` holds milliseconds — so the first argument has to
/// mention one of the duration-ish spellings this package actually uses:
/// `elapsed*`, `in(Milli|Micro)seconds`, or a name containing `time`, `times`,
/// `watch` or `duration`. The numeric literal may sit anywhere inside the
/// matcher, because `lessThanOrEqualTo(times.first + 1000)` is a threshold too
/// and an earlier version of this pattern missed exactly that one.
///
/// Deliberately blind to `typeCount`, `length` and `charsPerType`: those are
/// counts and sizes, identical on every machine, and gating on them is fine.
final _wallClockThreshold = RegExp(
  r'expect\(\s*[^,;]*\b(?:elapsed\w*|in(?:Milli|Micro)seconds|\w*[Tt]ime\w*|times|'
  r'\w*[Ww]atch\w*|\w*[Dd]uration\w*)\b[^,;]*,\s*'
  r'(?:lessThan|lessThanOrEqualTo|greaterThan|greaterThanOrEqualTo|closeTo)\s*'
  r'\([^)]*[0-9]',
  multiLine: true,
);

void main() {
  final target = p.join(
    Directory.current.path,
    'test',
    'reflection',
    'performance_test.dart',
  );

  group('SCD15: performance tests report rather than gate', () {
    test(
      'G-SCD15-1: performance_test.dart asserts no wall-clock threshold '
      '[2026-09-12] (PASS)',
      () {
        final source = File(target).readAsStringSync();
        final hits = _wallClockThreshold
            .allMatches(source)
            .map((m) => m.group(0)!.replaceAll(RegExp(r'\s+'), ' '))
            .toList();

        expect(
          hits,
          isEmpty,
          reason:
              'A duration is being compared against a constant again:\n'
              '${hits.map((h) => '  $h').join('\n')}\n\n'
              'That constant measures the machine, not the code — the same '
              'analysis in this file took 2.0 s alone, 3.5 s under suite load '
              'and 8.0 s on 2026-09-03. Emit a [PERF] line with reportPerf() '
              'and compare across runs instead. If a timing genuinely must '
              'gate, assert a RATIO against a reference operation measured in '
              'the same run, and say in a comment why the reference is sound.',
        );
      },
    );

    test(
      'G-SCD15-2: the guard is reading the file it means to [2026-09-12] '
      '(PASS)',
      () {
        // Anti-vacuity. G-SCD15-1 passes just as happily against a file that
        // was renamed, emptied, or never found — none of which it notices,
        // because "no matches" is what success looks like.
        final file = File(target);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'Expected $target. If the performance tests moved, move this '
              'guard with them rather than deleting it.',
        );

        final source = file.readAsStringSync();
        expect(
          source,
          contains('reportPerf('),
          reason:
              'The measurements should still be emitted; a file with neither '
              'thresholds nor reports has stopped measuring anything.',
        );
        expect(
          RegExp(r'\bStopwatch\(\)').allMatches(source).length,
          greaterThanOrEqualTo(5),
          reason:
              'The timings themselves must survive — the point was to stop '
              'gating on them, not to stop taking them.',
        );
      },
    );

    test(
      'G-SCD15-3: the pattern recognises the thresholds that were removed '
      '[2026-09-12] (PASS)',
      () {
        // The real removed lines, so a future narrowing of the pattern fails
        // here rather than quietly letting the next one back in.
        for (final removed in const [
          'expect(stopwatch.elapsedMilliseconds, lessThan(5000),',
          'expect(generationWatch.elapsedMilliseconds, lessThan(2000));',
          'expect(times.last, lessThanOrEqualTo(times.first + 1000),',
          'expect(watch1.elapsedMilliseconds, lessThan(10000));',
          'expect(analysisWatch.elapsedMilliseconds, lessThan(5000));',
          'expect(stopwatch.elapsedMilliseconds, lessThan(60000),',
        ]) {
          expect(
            _wallClockThreshold.hasMatch(removed),
            isTrue,
            reason: 'pattern no longer recognises: $removed',
          );
        }

        // And leaves the load-independent assertions alone. These are about
        // sizes and counts, which are the same on every machine.
        for (final kept in const [
          'expect(result.typeCount, greaterThan(0));',
          'expect(code.length, greaterThan(1000));',
          'expect(code.length, greaterThan(10000));',
          'expect(charsPerType, lessThan(50000),',
          'expect(result, isNotNull);',
          'expect(code, isNotEmpty);',
        ]) {
          expect(
            _wallClockThreshold.hasMatch(kept),
            isFalse,
            reason: 'pattern wrongly fires on: $kept',
          );
        }
      },
    );
  });
}
