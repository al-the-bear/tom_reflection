/// An extension type erases to its representation type at run time, so it has
/// no `Type` of its own: `Label` (over `String`) *is* `String` to a mirror
/// system keyed by `Type`. The generator must not give an extension type a
/// class mirror. When it did, the extension type's mirror was registered under
/// its representation type, after that type's own mirror, and replaced it:
/// `reflectType(String)` answered `Label`, and so did the type argument of
/// every `List<String>` field — `typeArguments.first.simpleName` was the
/// extension type's name. `tom_core`'s `TomOneShotResource` (an extension type
/// over `String`) did this to every `String` in the framework's seeds.
///
/// The test generates the fixture's mirror, runs a program against it, and
/// reads what the mirrors answer.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_reflection_generator/tom_reflection_generator.dart';

void main() {
  final packageRoot = Directory.current.path;
  final fixtures = p.join(packageRoot, 'test', 'fixtures');
  final fixture = p.join(fixtures, 'extension_type_fixture.dart');
  final generated = p.join(fixtures, 'extension_type_fixture.reflection.dart');
  final probe = p.join(fixtures, 'extension_type_probe.dart');

  late Map<String, Object?> answers;
  late String source;

  setUpAll(() async {
    final result = await generateReflection(
      projectRoot: packageRoot,
      targets: [fixture],
    );
    expect(result.failedCount, 0, reason: 'the fixture failed to generate');
    source = File(generated).readAsStringSync();
    File(probe).writeAsStringSync('''
import 'dart:convert';

import 'package:tom_reflection/tom_reflection.dart';

import 'extension_type_fixture.dart';
import 'extension_type_fixture.reflection.dart';

String nameOf(Type type) => fixtureReflection.reflectType(type).simpleName;

List<String> argumentsOf(String field) {
  final holder = fixtureReflection.reflectType(Holder) as ClassMirror;
  final variable = holder.declarations[field]! as VariableMirror;
  return [for (final a in variable.type.typeArguments) a.simpleName];
}

void main() {
  initializeReflection();
  print(jsonEncode({
    'String': nameOf(String),
    'Item': nameOf(Item),
    'tags': argumentsOf('tags'),
    'items': argumentsOf('items'),
  }));
}
''');
    final run = await Process.run(Platform.resolvedExecutable, ['run', probe]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    final line = '${run.stdout}'.trim().split('\n').last;
    answers = jsonDecode(line) as Map<String, Object?>;
  });

  tearDownAll(() {
    for (final path in [generated, probe]) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }
  });

  test('ET-1: an extension type gets no class mirror', () {
    expect(source, isNot(contains("r'Label'")));
    expect(source, isNot(contains("r'ItemRef'")));
  });

  test('ET-2: a type reflects as itself, not as an extension type over it', () {
    expect(answers['String'], 'String');
    expect(answers['Item'], 'Item');
  });

  test("ET-3: a List<String> field's type argument is String", () {
    expect(answers['tags'], ['String']);
  });

  test("ET-4: a List<Item> field's type argument is Item", () {
    expect(answers['items'], ['Item']);
  });
}
