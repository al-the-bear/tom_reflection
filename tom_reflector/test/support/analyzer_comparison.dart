import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart' as analysis_results;
import 'package:analyzer/dart/element/element.dart' as analyzer_elements;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_reflector/tom_reflector.dart';

Future<void> compareAnalyzerToJson({
  required String rootPath,
  required String barrelPath,
  required String jsonPath,
  required String packageName,
}) async {
  final jsonFile = File(jsonPath);
  final content = jsonFile.readAsStringSync();
  final analysisResult = JsonDeserializer.decode(content);

  final contextBuilder = AnalyzerContextBuilder();
  final collection = contextBuilder.build(
    rootPath: rootPath,
    includedPaths: [rootPath],
  );

  final context = collection.contextFor(barrelPath);
  final session = context.currentSession;
  final analyzedFiles = context.contextRoot.analyzedFiles();

  final classNames = analysisResult.allClasses.map((c) => c.qualifiedName).toSet();
  final enumNames = analysisResult.allEnums.map((e) => e.qualifiedName).toSet();
  final mixinNames = analysisResult.allMixins.map((m) => m.qualifiedName).toSet();
  final extensionNames = analysisResult.allExtensions.map((e) => e.qualifiedName).toSet();
  final extensionTypeNames =
      analysisResult.allExtensionTypes.map((e) => e.qualifiedName).toSet();
  final typeAliasNames = analysisResult.allTypeAliases.map((t) => t.qualifiedName).toSet();
  final functionNames = analysisResult.allFunctions.map((f) => f.qualifiedName).toSet();

  expect(classNames, isNotEmpty, reason: 'Expected classes in analysis result.');

  for (final path in analyzedFiles) {
    if (!path.endsWith('.dart')) {
      continue;
    }
    final result = await session.getResolvedLibrary(path);
    if (result is! analysis_results.ResolvedLibraryResult) {
      continue;
    }

    final library = result.element;
    final libraryUri = library.uri;
    if (!_isInPackage(libraryUri, rootPath, packageName)) {
      continue;
    }

    for (final element in library.classes) {
      _expectElement(classNames, element, 'class', rootPath);
    }
    for (final element in library.enums) {
      _expectElement(enumNames, element, 'enum', rootPath);
    }
    for (final element in library.mixins) {
      _expectElement(mixinNames, element, 'mixin', rootPath);
    }
    for (final element in library.extensions) {
      _expectElement(extensionNames, element, 'extension', rootPath);
    }
    for (final element in library.extensionTypes) {
      _expectElement(extensionTypeNames, element, 'extension type', rootPath);
    }
    for (final element in library.typeAliases) {
      _expectElement(typeAliasNames, element, 'type alias', rootPath);
    }
    for (final element in library.topLevelFunctions) {
      _expectElement(functionNames, element, 'function', rootPath);
    }
  }
}

/// The name the serializer would have written for [element].
///
/// A dumped qualified name is package-relative — that is what makes the dump
/// diffable across machines — so a live name has to be put in the same form
/// before the two can be compared. Building the expectation from the absolute
/// URI instead would fail here on every machine, which is not the question
/// this test asks.
String _qualifiedName(analyzer_elements.Element element, String rootPath) {
  final libraryUri = element.library?.uri.toString() ?? '';
  final name = element.displayName;
  for (final prefix in ['file://$rootPath/', '$rootPath/']) {
    if (libraryUri.startsWith(prefix)) {
      return '${libraryUri.substring(prefix.length)}.$name';
    }
  }
  return '$libraryUri.$name';
}

void _expectElement(
  Set<String> names,
  analyzer_elements.Element element,
  String kind,
  String rootPath,
) {
  final name = element.displayName;
  if (name.isEmpty) {
    return;
  }
  final qualifiedName = _qualifiedName(element, rootPath);
  expect(
    names,
    contains(qualifiedName),
    reason: 'Missing $kind $qualifiedName in JSON analysis.',
  );
}

bool _isInPackage(Uri uri, String rootPath, String packageName) {
  if (uri.scheme == 'package') {
    if (uri.pathSegments.isEmpty) return false;
    return uri.pathSegments.first == packageName;
  }
  if (uri.scheme == 'file') {
    final filePath = uri.toFilePath();
    return p.isWithin(rootPath, filePath);
  }
  return false;
}
