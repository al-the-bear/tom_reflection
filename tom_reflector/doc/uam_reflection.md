# UAM Reflection Run

`tool/run_uam_reflection.dart` drives `ReflectionGenerator` over `tom_uam_server`
and every `tom_*` package it reaches. It is the largest target in the workspace,
which is what makes it the useful one: a generator that copes with the UAM stack
copes with anything else here.

## Entry points

The script derives the workspace root from its own location and analyses:

- `tom_uam/tom_uam_server/bin/aa_server_start.dart`
- `tom_uam/tom_uam_codespec/lib/tom_uam_codespec.dart`
- `tom_ai/core/tom_core_kernel/lib/tom_core_kernel.dart`
- `tom_ai/reflection/tom_reflection/lib/tom_reflection.dart`
- `tom_ai/basics/tom_basics/lib/tom_basics.dart`
- `tom_ai/basics/tom_crypto/lib/tom_crypto.dart`

Dependency tracking is configured wide on purpose — type annotations enabled,
transitive, external, argument types included — and the marker annotations are
`tomReflection` and `TomReflectionInfo`.

## Running it

```bash
cd tom_ai/reflection/tom_reflector
dart run tool/run_uam_reflection.dart            # counts, then the tabular dump
dart run tool/run_uam_reflection.dart --tabular  # the dump alone
dart run tool/run_uam_reflection.dart --save     # also write the generated code
```

`--save` writes `ztmp/uam_generated.r.dart` under the workspace root. That is
scratch space, and deliberately so: the file is a few megabytes of generated
Dart that nothing in the tree compiles, so a committed copy is a photograph of
one run that no later run updates. Read it where it lands, or regenerate it.

The run prints how many classes, enums, mixins, extensions, global functions and
global variables it found, and how large the generated source is. Those numbers
move with the packages, so this document does not quote them — the run is the
answer.

## What the generated code contains

- Import prefixes for every referenced library
- Type indices for all classes and enums
- Invoker functions for methods, constructors, getters and setters
- The class type list, with superclass and interface relationships
- Field and method metadata arrays

Analyzed on its own the file reports thousands of issues, because it is written
to be included in a package rather than to stand alone; that is not a defect in
the output.
