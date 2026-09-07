import 'dart:convert';

import '../model/model.dart';

/// Serializes analysis results to JSON format.
class JsonSerializer {
  static String encode(AnalysisResult result) {
    final map = _JsonWriter().toMap(result);
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  static Map<String, dynamic> toMap(AnalysisResult result) {
    return _JsonWriter().toMap(result);
  }
}

class _JsonWriter {
  /// The analysed package's root, as an absolute path, or `null` when it
  /// cannot be determined. Every path in the output is written relative to it.
  String? _root;

  Map<String, dynamic> toMap(AnalysisResult result) {
    _root = result.rootPackage.rootPath;
    return {
      'id': result.id,
      'dartSdkVersion': result.dartSdkVersion,
      'analyzerVersion': result.analyzerVersion,
      'schemaVersion': result.schemaVersion,
      'rootPackageId': result.rootPackage.id,
      'packages': result.packages.values.map(_package).toList(),
      'libraries': result.libraries.values.map(_library).toList(),
      'files': result.files.values.map(_file).toList(),
      'errors': result.errors.map(_error).toList(),
      // Metadata is free-form, and the analyzer puts the barrel's location in
      // it, so it needs the same treatment as the typed path fields.
      'metadata': result.metadata.map(
        (key, value) =>
            MapEntry(key, value is String ? _relative(value) : value),
      ),
    };
  }

  /// [path] with the analysed root removed, so the output says where a file is
  /// in the package rather than where the package was on one machine.
  ///
  /// This is what makes the artifact diffable. An absolute path is the
  /// identity of the machine that ran the analysis, so a tracked snapshot
  /// regenerated anywhere else produces a whole-file diff carrying no content
  /// — which means it is never regenerated, and goes stale without anything
  /// failing. The `file://` scheme goes with it: a location inside a package
  /// is not a URL.
  ///
  /// A dependency's source is outside the root and cannot be relative to it,
  /// but it is not machine-specific either: everything before the pub cache is
  /// the reader's home directory and everything after it is the package,
  /// version and file. The prefix is replaced by a `pub-cache:` marker, which
  /// keeps the part that identifies the source and drops the part that
  /// identifies the machine.
  ///
  /// Anything else — an SDK path, a sibling checkout — is left alone. Those
  /// genuinely differ between hosts, and inventing a relative form for them
  /// would make the artifact look portable while not being it.
  String _relative(String path) {
    final root = _root;
    if (root != null && root.isNotEmpty) {
      for (final prefix in ['file://$root/', '$root/']) {
        if (path.startsWith(prefix)) return path.substring(prefix.length);
      }
      if (path == root) return '.';
    }
    const cache = '/.pub-cache/';
    final at = path.indexOf(cache);
    if (at >= 0) return 'pub-cache:${path.substring(at + cache.length)}';
    return path;
  }

  Map<String, dynamic> _package(PackageInfo pkg) {
    return {
      'id': pkg.id,
      'name': pkg.name,
      'version': pkg.version,
      'rootPath': _relative(pkg.rootPath),
      'isRoot': pkg.isRoot,
      'libraries': pkg.libraries.map((l) => l.id).toList(),
      'dependencies': pkg.dependencies.keys.toList(),
      'devDependencies': pkg.devDependencies.keys.toList(),
    };
  }

  Map<String, dynamic> _library(LibraryInfo lib) {
    return {
      'id': lib.id,
      'name': lib.name,
      'uri': _relative(lib.uri.toString()),
      'packageId': lib.package.id,
      'mainSourceFileId': lib.mainSourceFile.id,
      'partFileIds': lib.partFiles.map((f) => f.id).toList(),
      'documentation': lib.documentation,
      'annotations': lib.annotations.map(_annotation).toList(),
      'isDeprecated': lib.isDeprecated,
      'classes': lib.classes.map(_class).toList(),
      'enums': lib.enums.map(_enum).toList(),
      'mixins': lib.mixins.map(_mixin).toList(),
      'extensions': lib.extensions.map(_extension).toList(),
      'extensionTypes': lib.extensionTypes.map(_extensionType).toList(),
      'typeAliases': lib.typeAliases.map(_typeAlias).toList(),
      'functions': lib.functions.map(_function).toList(),
      'variables': lib.variables.map(_variable).toList(),
      'getters': lib.getters.map(_getter).toList(),
      'setters': lib.setters.map(_setter).toList(),
      'imports': lib.imports.map(_import).toList(),
      'exports': lib.exports.map(_export).toList(),
    };
  }

  Map<String, dynamic> _file(FileInfo file) {
    return {
      'id': file.id,
      'path': _relative(file.path),
      'packageId': file.package.id,
      'libraryId': file.library?.id,
      'isPart': file.isPart,
      'partOfDirective': file.partOfDirective,
      'lines': file.lines,
      'contentHash': file.contentHash,
    };
  }

  Map<String, dynamic> _error(AnalysisError error) {
    return {
      'message': error.message,
      'severity': error.severity.name,
      'location': error.location != null
          ? {
              'line': error.location!.line,
              'column': error.location!.column,
              'offset': error.location!.offset,
              'length': error.location!.length,
            }
          : null,
      'code': error.code,
    };
  }

  Map<String, dynamic> _class(ClassInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'libraryId': info.library.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'isAbstract': info.isAbstract,
      'isSealed': info.isSealed,
      'isFinal': info.isFinal,
      'isBase': info.isBase,
      'isInterface': info.isInterface,
      'isMixin': info.isMixin,
      'superclass': info.superclass != null
          ? _typeReference(info.superclass!)
          : null,
      'interfaces': info.interfaces.map(_typeReference).toList(),
      'mixins': info.mixins.map(_typeReference).toList(),
      'typeParameters': info.typeParameters.map(_typeParameter).toList(),
      'constructors': info.constructors.map(_constructor).toList(),
      'methods': info.methods.map(_method).toList(),
      'fields': info.fields.map(_field).toList(),
      'getters': info.getters.map(_getter).toList(),
      'setters': info.setters.map(_setter).toList(),
    };
  }

  Map<String, dynamic> _enum(EnumInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'libraryId': info.library.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'values': info.values.map(_enumValue).toList(),
      'interfaces': info.interfaces.map(_typeReference).toList(),
      'mixins': info.mixins.map(_typeReference).toList(),
      'fields': info.fields.map(_field).toList(),
      'methods': info.methods.map(_method).toList(),
      'getters': info.getters.map(_getter).toList(),
      'setters': info.setters.map(_setter).toList(),
      'constructors': info.constructors.map(_constructor).toList(),
    };
  }

  Map<String, dynamic> _mixin(MixinInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'libraryId': info.library.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'onTypes': info.onTypes.map(_typeReference).toList(),
      'implementsTypes': info.implementsTypes.map(_typeReference).toList(),
      'typeParameters': info.typeParameters.map(_typeParameter).toList(),
      'methods': info.methods.map(_method).toList(),
      'fields': info.fields.map(_field).toList(),
      'getters': info.getters.map(_getter).toList(),
      'setters': info.setters.map(_setter).toList(),
    };
  }

  Map<String, dynamic> _extension(ExtensionInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'libraryId': info.library.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'extendedType': _typeReference(info.extendedType),
      'typeParameters': info.typeParameters.map(_typeParameter).toList(),
      'methods': info.methods.map(_method).toList(),
      'fields': info.fields.map(_field).toList(),
      'getters': info.getters.map(_getter).toList(),
      'setters': info.setters.map(_setter).toList(),
    };
  }

  Map<String, dynamic> _extensionType(ExtensionTypeInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'libraryId': info.library.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'representationType': _typeReference(info.representationType),
      'primaryConstructor': info.primaryConstructor != null
          ? _constructor(info.primaryConstructor!)
          : null,
      'typeParameters': info.typeParameters.map(_typeParameter).toList(),
      'methods': info.methods.map(_method).toList(),
      'fields': info.fields.map(_field).toList(),
      'getters': info.getters.map(_getter).toList(),
      'setters': info.setters.map(_setter).toList(),
      'constructors': info.constructors.map(_constructor).toList(),
    };
  }

  Map<String, dynamic> _typeAlias(TypeAliasInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'libraryId': info.library.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'aliasedType': _typeReference(info.aliasedType),
      'typeParameters': info.typeParameters.map(_typeParameter).toList(),
    };
  }

  Map<String, dynamic> _function(FunctionInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'libraryId': info.library.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'returnType': _typeReference(info.returnType),
      'typeParameters': info.typeParameters.map(_typeParameter).toList(),
      'parameters': info.parameters.map(_parameter).toList(),
      'isAsync': info.isAsync,
      'isGenerator': info.isGenerator,
      'isExternal': info.isExternal,
      'isStatic': info.isStatic,
    };
  }

  Map<String, dynamic> _variable(VariableInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'libraryId': info.library.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'type': _typeReference(info.type),
      'isFinal': info.isFinal,
      'isConst': info.isConst,
      'isLate': info.isLate,
      'isStatic': info.isStatic,
      'hasInitializer': info.hasInitializer,
      'hasGetter': info.hasGetter,
      'hasSetter': info.hasSetter,
    };
  }

  Map<String, dynamic> _field(FieldInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'declaringTypeId': info.declaringType?.id,
      'owningLibraryId': info.owningLibrary?.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'type': _typeReference(info.type),
      'isFinal': info.isFinal,
      'isConst': info.isConst,
      'isLate': info.isLate,
      'isStatic': info.isStatic,
      'hasInitializer': info.hasInitializer,
      'hasGetter': info.hasGetter,
      'hasSetter': info.hasSetter,
    };
  }

  Map<String, dynamic> _method(MethodInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'declaringTypeId': info.declaringType?.id,
      'owningLibraryId': info.owningLibrary?.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'returnType': _typeReference(info.returnType),
      'typeParameters': info.typeParameters.map(_typeParameter).toList(),
      'parameters': info.parameters.map(_parameter).toList(),
      'isAsync': info.isAsync,
      'isGenerator': info.isGenerator,
      'isExternal': info.isExternal,
      'isStatic': info.isStatic,
      'isAbstract': info.isAbstract,
      'isOperator': info.isOperator,
    };
  }

  Map<String, dynamic> _constructor(ConstructorInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'declaringTypeId': info.declaringType.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'parameters': info.parameters.map(_parameter).toList(),
      'isAsync': info.isAsync,
      'isExternal': info.isExternal,
      'isStatic': info.isStatic,
      'isConst': info.isConst,
      'isFactory': info.isFactory,
      'redirectedConstructor': info.redirectedConstructor,
      'superConstructorInvocation': info.superConstructorInvocation,
    };
  }

  Map<String, dynamic> _getter(GetterInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'declaringTypeId': info.declaringType?.id,
      'owningLibraryId': info.owningLibrary?.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'returnType': _typeReference(info.returnType),
      'parameters': info.parameters.map(_parameter).toList(),
      'isAsync': info.isAsync,
      'isExternal': info.isExternal,
      'isStatic': info.isStatic,
      'isAbstract': info.isAbstract,
    };
  }

  Map<String, dynamic> _setter(SetterInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'declaringTypeId': info.declaringType?.id,
      'owningLibraryId': info.owningLibrary?.id,
      'sourceFileId': info.sourceFile.id,
      'location': _location(info.location),
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
      'isDeprecated': info.isDeprecated,
      'parameter': _parameter(info.parameter),
      'isAsync': info.isAsync,
      'isExternal': info.isExternal,
      'isStatic': info.isStatic,
      'isAbstract': info.isAbstract,
    };
  }

  Map<String, dynamic> _enumValue(EnumValueInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'parentEnumId': info.parentEnum.id,
      'index': info.index,
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
    };
  }

  Map<String, dynamic> _annotation(AnnotationInfo info) {
    return {
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'constructorName': info.constructorName,
      'namedArguments': info.namedArguments.map(
        (key, value) => MapEntry(key, value.value),
      ),
      'positionalArguments': info.positionalArguments
          .map((value) => value.value)
          .toList(),
    };
  }

  Map<String, dynamic> _typeReference(TypeReference info) {
    return {
      'id': info.id,
      'name': info.name,
      'qualifiedName': _relative(info.qualifiedName),
      'typeArguments': info.typeArguments.map(_typeReference).toList(),
      'isNullable': info.isNullable,
      'isDynamic': info.isDynamic,
      'isVoid': info.isVoid,
      'isFunction': info.isFunction,
      'functionType': info.functionType != null
          ? _functionType(info.functionType!)
          : null,
      'definitionLibraryId': info.definitionLibrary?.id,
      'isTypeParameter': info.isTypeParameter,
      'typeParameterBound': info.typeParameterBound != null
          ? _typeReference(info.typeParameterBound!)
          : null,
      'resolvedElementId': info.resolvedElement?.id,
    };
  }

  Map<String, dynamic> _functionType(FunctionTypeInfo info) {
    return {
      'id': info.id,
      'returnType': _typeReference(info.returnType),
      'typeParameters': info.typeParameters.map(_typeParameter).toList(),
      'parameters': info.parameters.map(_parameter).toList(),
    };
  }

  Map<String, dynamic> _typeParameter(TypeParameterInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'bound': info.bound != null ? _typeReference(info.bound!) : null,
      'defaultType': info.defaultType != null
          ? _typeReference(info.defaultType!)
          : null,
      'variance': info.variance?.name,
    };
  }

  Map<String, dynamic> _parameter(ParameterInfo info) {
    return {
      'id': info.id,
      'name': info.name,
      'type': _typeReference(info.type),
      'isRequired': info.isRequired,
      'isNamed': info.isNamed,
      'isPositional': info.isPositional,
      'hasDefaultValue': info.hasDefaultValue,
      'defaultValue': info.defaultValue,
      'documentation': info.documentation,
      'annotations': info.annotations.map(_annotation).toList(),
    };
  }

  Map<String, dynamic> _location(SourceLocation location) {
    return {
      'line': location.line,
      'column': location.column,
      'offset': location.offset,
      'length': location.length,
    };
  }

  Map<String, dynamic> _import(ImportInfo info) {
    return {
      'importingLibraryId': info.importingLibrary.id,
      'importedLibraryId': info.importedLibrary.id,
      'prefix': info.prefix,
      'isDeferred': info.isDeferred,
      'show': info.show,
      'hide': info.hide,
      'documentation': info.documentation,
    };
  }

  Map<String, dynamic> _export(ExportInfo info) {
    return {
      'exportingLibraryId': info.exportingLibrary.id,
      'exportedLibraryId': info.exportedLibrary.id,
      'show': info.show,
      'hide': info.hide,
      'documentation': info.documentation,
    };
  }
}
