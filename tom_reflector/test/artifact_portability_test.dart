// SCD13 (scd13_aicx): no tracked file may name the machine that produced it.
//
// The original symptom was `doc/analyzer_analysis.json`, a committed golden
// holding `file:///srv/repos/...` URIs from a Linux fleet host. Two analyzer
// tests compared a live analysis against it, so they were green on exactly one
// machine at a time and regenerating the golden moved the failure rather than
// removing it. That file is gone — tcincb86_ahul deleted both dumps and had
// `compareAnalyzerToJson` produce its input in-process instead.
//
// What was missing was anything to keep it gone. A later sweep took 790
// absolute paths out of the thirteen build-example snapshots and left no test
// behind, so the property held only until the next artifact was committed —
// and by the time this test was written, four had been: two `source_info`
// dumps naming a workspace layout that no longer exists, and a testkit run
// naming `/srv/repos/...`, the very signature the original todo described.
//
// This is a property about TRACKED files, so it asks git what is tracked
// rather than walking the directory: an artifact that is generated and
// gitignored is free to name whatever machine made it, and only a committed
// one can travel to another host and be wrong there.

library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Absolute paths that identify a particular machine or fleet host.
///
/// `/Users/<name>/` is macOS, `/home/<name>/` is Linux, `/srv/repos/` is where
/// the fleet's Linux hosts keep the workspace. A path under any of them is one
/// that cannot be true on a second machine.
final _machinePath = RegExp(r'(file://)?/(Users|home|srv)/[A-Za-z0-9_.-]+/');

/// Tracked paths exempt from the rule, each for a stated reason.
///
/// `tool/` holds ad-hoc exploration scripts that `analysis_options.yaml`
/// already excludes from analysis: not shipped, not imported by `lib/` or
/// `test/`, and several hardcode a `Code/tom2/...` root from a workspace layout
/// that no longer exists. They are exempt because repairing them is a separate
/// question — whether they should exist at all — not because naming a machine
/// is acceptable there. See the sce todo filed with this test.
bool _exempt(String relative) => p.split(relative).first == 'tool';

/// Binary files, where a path-shaped byte run means nothing.
const _binaryExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.pdf', '.ico'};

List<String> _trackedFiles(String packageRoot) {
  final result = Process.runSync('git', [
    'ls-files',
  ], workingDirectory: packageRoot);
  if (result.exitCode != 0) {
    fail('git ls-files failed in $packageRoot: ${result.stderr}');
  }
  return const LineSplitter()
      .convert(result.stdout as String)
      .where((l) => l.trim().isNotEmpty)
      .toList();
}

void main() {
  final packageRoot = Directory.current.path;

  group('SCD13: tracked artifacts are machine-independent', () {
    test(
      'G-SCD13X-1: no tracked file contains a machine-specific absolute path '
      '[2026-09-12] (PASS)',
      () {
        final offenders = <String, int>{};

        for (final relative in _trackedFiles(packageRoot)) {
          if (_exempt(relative)) continue;
          if (_binaryExtensions.contains(p.extension(relative).toLowerCase())) {
            continue;
          }
          final file = File(p.join(packageRoot, relative));
          if (!file.existsSync()) continue;

          final String content;
          try {
            content = file.readAsStringSync();
          } on FileSystemException {
            continue; // Not text after all.
          }

          final hits = _machinePath.allMatches(content).length;
          if (hits > 0) offenders[relative] = hits;
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'These tracked files name the machine that produced them, so '
              'they are wrong on every other machine in the fleet:\n'
              '${offenders.entries.map((e) => '  ${e.value} in ${e.key}').join('\n')}\n\n'
              'A generated artifact belongs in a gitignored folder — testkit '
              'output in testlog/, not doc/ — and a committed one must carry '
              'package-relative or workspace-relative paths. Regenerating it '
              'here only moves the failure to the next host.',
        );
      },
    );

    test(
      'G-SCD13X-2: the scan actually reads tracked text files [2026-09-12] '
      '(PASS)',
      () {
        // Anti-vacuity. G-SCD13X-1 passes just as happily when `git ls-files`
        // returns nothing, when every file is exempt, or when the working
        // directory is not what the test assumes — none of which it would
        // notice. It is a scan, so what it scanned has to be asserted.
        final tracked = _trackedFiles(packageRoot);
        expect(tracked, isNotEmpty, reason: 'git ls-files returned nothing');

        final scanned = tracked
            .where((f) => !_exempt(f))
            .where(
              (f) => !_binaryExtensions.contains(p.extension(f).toLowerCase()),
            )
            .where((f) => File(p.join(packageRoot, f)).existsSync())
            .toList();

        expect(
          scanned.length,
          greaterThan(100),
          reason:
              'Only ${scanned.length} files were in scope; this package tracks '
              'several hundred. Something narrowed the scan.',
        );
        expect(
          scanned,
          contains('pubspec.yaml'),
          reason: 'a file that must always be in scope',
        );
      },
    );

    test(
      'G-SCD13X-3: the pattern recognises the paths this defect was made of '
      '[2026-09-12] (PASS)',
      () {
        // The three forms actually found in this package's history, so a
        // future narrowing of the pattern fails here rather than silently
        // letting the next one through.
        const seen = [
          // The golden deleted by tcincb86_ahul.
          'file:///srv/repos/al_the_bear/tom_ai/reflection/x.dart',
          // doc/generated/dart_overview/source_info.json, Feb 2026.
          'file:///Users/alexiskyaw/Desktop/Code/tom2/xternal/x.dart',
          // A Linux developer checkout.
          '/home/alexis/al_the_bear/x.dart',
        ];
        for (final path in seen) {
          expect(
            _machinePath.hasMatch(path),
            isTrue,
            reason: 'pattern no longer recognises $path',
          );
        }

        // And does not fire on the portable forms the serializers emit.
        for (final portable in const [
          'package:tom_reflector/src/analyzer/analyzer_runner.dart',
          'workspace:tom_ai/core/tom_core_kernel/lib/kernel.dart',
          'lib/src/reflection/runtime/class_mirror.dart',
          'dart:core',
        ]) {
          expect(
            _machinePath.hasMatch(portable),
            isFalse,
            reason: 'pattern wrongly fires on $portable',
          );
        }
      },
    );

    test(
      'G-SCD13X-4: testkit output is not tracked under doc/ [2026-09-12] '
      '(PASS)',
      () {
        // The specific mistake that reintroduced the defect: testkit writes
        // `last_testrun.json` and `baseline_*.csv`, both of which record the
        // absolute path of every test file on the machine that ran them.
        // `testlog/` is gitignored for exactly this reason; `doc/` is not.
        final stray = _trackedFiles(packageRoot)
            .where(
              (f) =>
                  p.basename(f) == 'last_testrun.json' ||
                  (p.basename(f).startsWith('baseline_') &&
                      p.extension(f) == '.csv'),
            )
            .toList();

        expect(
          stray,
          isEmpty,
          reason:
              'Testkit artifacts belong in the gitignored testlog/, never in '
              'doc/ — a committed one is a photograph of one machine\'s run '
              'that nothing updates. Found: $stray',
        );
      },
    );
  });
}
