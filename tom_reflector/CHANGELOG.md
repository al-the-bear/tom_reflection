## Unreleased

### Changed — `tool/` runs anywhere, and `doc/` holds only what a person wrote

- `analyze_uam_full`, `find_annotations` and `run_cross_reference` named a
  workspace that no longer exists (`Code/tom2`) and failed at their first entry
  point. They share `tool/uam_targets.dart` with `run_uam_reflection` now — one
  list of UAM entry points, derived from the workspace root the scripts find
  from their own location (`tool/workspace.dart`) — and each runs end to end.
- `extract_analyzer_element_api` looked for "the newest analyzer 8.x in the pub
  cache" and found none once the dependency moved to 10.x. It reads the
  analyzer this package resolves instead.
- Every tool writes its output under the workspace's untracked
  `ztmp/tom_reflector/<name>/`, never into `doc/`. The generated files `doc/`
  carried — the `doc/generated/` trees, three tabular dumps, the element-API
  extraction, and `tool/uam_full_analysis.txt` — are untracked, together with
  `doc/uam_analyzer.md`, a record of one run against the dead workspace.
- `tool/test_analyzer.dart` is removed: it analysed the barrel of the package's
  former name and had outlived its question.
- `doc/tom_analyzer_design.md` opens by stating that it is the original design
  record, where the code has diverged from it, and which documents describe the
  package as it is.

## 1.3.0

### Added — `-n` on reflector, analyzer and reflection_analyzer (scf11)

All three declared `dryRun: false` — nothing read `args.dryRun`, so
tom_build_base refused `-n`. They write files (the reflection output, the
analysis YAML/JSON), so a preview is meaningful: every write now goes through
`writeOrPreview`, which under `-n` prints `[DRY RUN] Would create` /
`Would update` for each output that would change and writes nothing. Analysis
printed to stdout is unaffected.

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
