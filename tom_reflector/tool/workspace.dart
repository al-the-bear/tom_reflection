/// Where the `tool/` scripts find the workspace and put what they produce.
library;

import 'dart:io';

/// The workspace root, derived from the running script's own location.
///
/// A constant absolute path is right on exactly one machine and names a
/// directory that does not exist on any of the others, so a script built on
/// one fails at its first path with a message about a file nobody recognises.
/// This walks up from `<workspace>/tom_ai/reflection/tom_reflector/tool/`
/// instead, so it is correct wherever the tree is cloned.
String get workspaceRoot {
  var dir = File.fromUri(Platform.script).parent.parent; // …/tom_reflector
  for (var i = 0; i < 3; i++) {
    dir = dir.parent; // reflection → tom_ai → workspace root
  }
  return dir.path;
}

/// A directory for [name]'s output under the workspace's untracked `ztmp/`,
/// created if absent.
///
/// What these scripts produce is the output of one run on one machine. The
/// package's `doc/` holds what a person wrote, and a generated file committed
/// there is a snapshot no later run updates, so a reader cannot tell it from a
/// current one. `ztmp/` is the workspace's scratch space and is never tracked.
Directory scratchDirectory(String name) =>
    Directory('$workspaceRoot/ztmp/tom_reflector/$name')
      ..createSync(recursive: true);
