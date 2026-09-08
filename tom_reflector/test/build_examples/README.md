# Build Examples

These test projects demonstrate how to use the `tom_analyzer` package with
the standalone CLI tools for code analysis and reflection generation.

## Projects

| Project | Tool | Target | Description |
|---------|------|--------|-------------|
| `analyze_analyzer` | Analyzer | analyzer | Analyzes the analyzer package itself |
| `analyze_dart_overview` | Analyzer | dart_overview | Analyzes the dart_overview fixture |
| `analyze_tom_core_kernel` | Analyzer | tom_core_kernel | Analyzes tom_core_kernel |
| `analyze_tom_core_server` | Analyzer | tom_core_server | Analyzes tom_core_server |
| `analyzer_demo` | Both | sample_code | Demonstrates both analysis and reflection |
| `reflect_analyzer` | Reflector | analyzer | Generates reflection for analyzer |
| `reflect_dart_overview` | Reflector | dart_overview | Generates reflection for dart_overview |
| `reflect_tom_core_kernel` | Reflector | tom_core_kernel | Generates reflection for tom_core_kernel |
| `reflect_tom_core_server` | Reflector | tom_core_server | Generates reflection for tom_core_server |

## Running Build Examples

The two CLI tools ship in this package's `bin/`, so they are run through it by
name. `buildkit.yaml` is picked up from the working directory — there is no
`--config` flag.

```bash
cd <project>
dart pub get

# For analysis projects:
dart run tom_reflector:reflection_analyzer

# For reflection projects:
dart run tom_reflector:reflector
```

Both write to stdout unless told otherwise, so regenerating a committed
snapshot names its file:

```bash
dart run tom_reflector:reflection_analyzer \
  --barrel lib/main.dart --output lib/main.analysis.yaml
```

The `reflect_*` projects carry a second snapshot, `main.r.analysis.yaml`: the
same analysis run over the generated `lib/main.r.dart` rather than the hand-
written barrel, which is what shows the generated barrel reaching the same
surface.

A regenerated snapshot records paths relative to the package it describes, so
running this on any machine is a no-op when nothing has changed — which is what
makes a stale one visible as a real diff rather than as a rewrite of somebody's
home directory.

## Configuration Files

Each project contains:

- `pubspec.yaml` - Package configuration with the `tom_reflector` path dependency
- `buildkit.yaml` - Standalone tool configuration (tom_analyzer/tom_reflector sections)
- `lib/` - Target source files or imports
