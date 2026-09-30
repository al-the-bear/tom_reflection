/// End-to-end guard: a constructor closure for a class with a **bounded** type
/// parameter must compile.
///
/// The generator emits one closure per constructor, of the shape
/// `(bool b) => (low, high) => b ? prefix1.NumRange(low, high) : null`. Its
/// parameters are untyped, so they are `dynamic`, and inference then picks
/// `dynamic` for the class's type argument too — which violates a bound such
/// as `T extends num`. The analyzer reports TYPE_ARGUMENT_NOT_MATCHING_BOUNDS
/// and COULD_NOT_INFER at every such site, and the generated library does not
/// compile. `tom_uam_client`'s entry-point mirror carried ten of these errors,
/// from Flutter's `NumRange` and `DateTimeRange`, `TomObservableEnum` and
/// others; its tests passed only because none of them imported the mirror, and
/// the analyzer was silent because generated files are excluded from analysis.
///
/// **Whether it fails depends on the consumer's language version.** From Dart
/// 3.7, "inference using bounds" infers the bound for a bounded parameter fed
/// `dynamic`, and the same closure compiles. A generated library is analyzed
/// at the language version of the package it is generated into, so a consumer
/// whose `pubspec.yaml` still says `sdk: '>=3.0.0'` — `tom_uam_client` — is on
/// 3.0 and meets the error, while this package (3.10) never would. Generated
/// code must not depend on which version its consumer declares.
///
/// So this test runs the analyzer on the generated library, by name, twice:
/// as generated, and as a pre-3.7 consumer would see it (a `// @dart=3.6`
/// override on a copy). Both must be free of errors. The property that matters
/// is that the mirror compiles, and nothing short of the analyzer observes it.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_reflection_generator/tom_reflection_generator.dart';

String _flatten(String source) => source.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  final packageRoot = Directory.current.path;
  final fixture = p.join(
    packageRoot,
    'test',
    'fixtures',
    'bounded_generic_constructor_fixture.dart',
  );
  final generated = p.join(
    packageRoot,
    'test',
    'fixtures',
    'bounded_generic_constructor_fixture.reflection.dart',
  );

  late String flat;

  setUpAll(() async {
    final result = await generateReflection(
      projectRoot: packageRoot,
      targets: [fixture],
      options: const ReflectionGenerationOptions(noCache: true),
    );
    expect(result.failedCount, 0, reason: 'the fixture failed to generate');
    expect(result.processedCount, 1, reason: 'the fixture was skipped');
    flat = _flatten(File(generated).readAsStringSync());
  });

  tearDownAll(() {
    final file = File(generated);
    if (file.existsSync()) file.deleteSync();
  });

  Future<List<String>> errorsIn(String path) async {
    final analysis = await Process.run(Platform.resolvedExecutable, [
      'analyze',
      '--format=machine',
      path,
    ]);
    return '${analysis.stdout}${analysis.stderr}'
        .split('\n')
        .where((line) => line.startsWith('ERROR|'))
        .toList();
  }

  test('the generated library analyzes with no error', () async {
    expect(await errorsIn(generated), isEmpty);
  });

  test(
    'it analyzes with no error for a consumer below language 3.7 too',
    () async {
      // Before "inference using bounds", `NumRange(low, high)` with dynamic
      // arguments infers `NumRange<dynamic>` and violates `T extends num`.
      final pinned = p.join(
        packageRoot,
        'test',
        'fixtures',
        'bounded_generic_constructor_fixture.dart36.dart',
      );
      File(pinned).writeAsStringSync(
        '// @dart=3.6\n${File(generated).readAsStringSync()}',
      );
      addTearDown(() => File(pinned).deleteSync());
      expect(
        await errorsIn(pinned),
        isEmpty,
        reason:
            'a constructor closure a pre-3.7 consumer cannot compile — a '
            'bounded type parameter inferred as dynamic',
      );
    },
  );

  group('a bounded class is instantiated at its bounds', () {
    test('a core bound', () {
      expect(flat, matches(RegExp(r'prefix\d+\.NumRange<num>\(low, high\)')));
    });

    test('an Enum bound', () {
      expect(flat, matches(RegExp(r'prefix\d+\.EnumBox<Enum>\(')));
    });

    test('a generic bound, with its own type argument', () {
      expect(
        flat,
        matches(RegExp(r'prefix\d+\.Numbers<List<num>>\.of\(values\)')),
      );
    });

    test('an unbounded parameter beside a bounded one takes dynamic', () {
      expect(flat, matches(RegExp(r'prefix\d+\.Keyed<Object, dynamic>\(')));
    });

    test('an unbounded class is emitted as before, with no type arguments', () {
      expect(flat, matches(RegExp(r'prefix\d+\.Plain\(value\)')));
    });
  });
}
