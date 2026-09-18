## 1.2.0

### Changed — `-n` / `--dry-run` is now refused rather than silently ignored

The analyzer, reflection-analyzer and reflector tools do not implement a
dry-run mode: nothing in the package reads `args.dryRun`, so `-n` used to be
accepted and the work done anyway, while the help advertised the flag.

tom_build_base 2.12.0 makes the `NavigationFeatures.dryRun` declaration
load-bearing, so `-n` now exits non-zero, and the help no longer offers it.

Requires tom_build_base >=2.12.0.

## 1.1.0

### Removed — `lib/src/ast/`, an unreachable copier that had stopped compiling (scd12_aicx)

`lib/src/ast/` held ~196 KB across `converter.dart`, `visitor.dart`,
`token.dart`, `serializable_ast.dart` and `nodes/node.dart`, all dated
2026-02-25. It duplicated what `tom_ast_generator` is documented to own: the
1:1 walk of the analyzer AST into the mirror `SAstNode` tree.

It was exported by no barrel, imported by nothing, and covered by no test —
and, measured rather than assumed, **it no longer compiled**. Analysed with
its `analysis_options.yaml` exclusion lifted it reports **855 errors**: 294
undefined named parameters, 288 missing required arguments, 143 undefined
identifiers, 12 unresolvable URIs. It was written against an earlier shape of
`tom_ast_model` and never updated; node types it constructs (`SScriptTag`,
`SConfiguration`, `SDottedName`, `SLibraryIdentifier`, `STypeAlias`) do not
exist in the `tom_ast_model` it declared a dependency on.

The `analyzer: exclude:` entry that hid this — annotated "AST module is
incomplete (WIP)" — is removed with it.

The subtree was the sole reason this package depended on `tom_ast_model`, so
that dependency is dropped too.

## 1.0.0

- Initial version.
