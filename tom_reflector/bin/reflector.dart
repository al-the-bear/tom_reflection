/// Tom Reflector CLI — code reflection generation tool.
///
/// Run `reflector --help` for usage information.
library;

import 'dart:io';

import 'package:tom_build_base/tom_build_base_v2.dart';
import 'package:tom_reflector/src/v2/reflector_executor.dart';
import 'package:tom_reflector/src/v2/reflector_tool.dart';

// Inside the shared console-markdown zone (tom_build_base), as buildkit and
// testkit run: output renders the same, and a reader that stops early
// (`| head -1`) ends the run quietly instead of with an unhandled EPIPE.
Future<void> main(List<String> args) => runWithConsoleMarkdown(() async {
  final runner = ToolRunner(
    tool: reflectorTool,
    executors: <String, CommandExecutor>{'default': ReflectorExecutor()},
  );

  final result = await runner.run(args);

  if (!result.success) {
    exitCode = 1;
  }
});
