/// SCF14 — the reflection generator names a locked package the pub cache
/// cannot supply, instead of generating a smaller mirror.
///
/// The generator reads RESOLVED element models to decide what a type exposes.
/// A locked package missing from the cache produces no resolution error — the
/// lock is satisfiable, so `dart pub get` reports success — the analyzer then
/// reports `Undefined name` at each use, and a generator that tolerates link
/// failures emits a reduced capability set with exit 0. d4rtgen, buildkit
/// `:compiler` and `:runner` already check first (SCE38); this pins the same
/// check here, before anything reads a dependency's sources.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_reflection_generator/src/generation/reflection_generation.dart';

/// A scratch directory under the workspace's `ztmp/` — never the system temp.
Directory _scratch(String label) {
  var dir = Directory.current;
  while (!Directory(p.join(dir.path, 'ztmp')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('no ztmp/ found');
    dir = parent;
  }
  return Directory(
    p.join(
      dir.path,
      'ztmp',
      'scf14_${label}_${DateTime.now().microsecondsSinceEpoch}',
    ),
  )..createSync(recursive: true);
}

/// A project whose lock names one hosted package, `zzz_locked` 1.0.0.
Directory _project(Directory scratch) {
  final project = Directory(p.join(scratch.path, 'project'))..createSync();
  File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync(
    'name: scf14_probe\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n',
  );
  File(p.join(project.path, 'pubspec.lock')).writeAsStringSync('''
packages:
  zzz_locked:
    dependency: "direct main"
    description:
      name: zzz_locked
      sha256: "00"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.0"
sdks:
  dart: ">=3.0.0 <4.0.0"
''');
  return project;
}

void main() {
  late Directory scratch;
  setUp(() => scratch = _scratch('preflight'));
  tearDown(() {
    if (scratch.existsSync()) scratch.deleteSync(recursive: true);
  });

  test('F-SCF14-1: a locked package the cache cannot supply is named, and '
      'nothing is generated [2026-09-29] (PASS)', () async {
    final project = _project(scratch);
    final cache = Directory(p.join(scratch.path, 'cache'))..createSync();

    final result = await generateReflection(
      projectRoot: project.path,
      targets: const ['lib'],
      options: ReflectionGenerationOptions(
        noCache: true,
        pubCachePath: cache.path,
      ),
    );

    expect(result.hasPubCacheProblem, isTrue);
    expect(result.pubCacheReport, contains('zzz_locked'));
    expect(result.processedCount, 0);
    expect(result.noFilesMatched, isFalse, reason: 'it stopped before that');
  });

  test('F-SCF14-2 (control): a project whose locked packages are all cached '
      'is not stopped [2026-09-29] (PASS)', () async {
    final project = _project(scratch);
    final cache = Directory(p.join(scratch.path, 'cache'));
    // A healthy cached package is a directory WITH its pubspec — an empty
    // directory is the second damage shape, which pub resolves straight past.
    final cached = Directory(
      p.join(cache.path, 'hosted', 'pub.dev', 'zzz_locked-1.0.0'),
    )..createSync(recursive: true);
    File(
      p.join(cached.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: zzz_locked\nversion: 1.0.0\n');

    final result = await generateReflection(
      projectRoot: project.path,
      targets: const ['lib'],
      options: ReflectionGenerationOptions(
        noCache: true,
        pubCachePath: cache.path,
      ),
    );

    expect(result.hasPubCacheProblem, isFalse);
    // Past the pre-flight, the empty probe project simply has nothing to do.
    expect(result.noFilesMatched, isTrue);
  });
}
