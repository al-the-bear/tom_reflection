/// Writing a generated output — or, under `-n`, saying what would be written.
library;

import 'dart:io';

/// Writes [content] to [path], creating its directory; with [dryRun] writes
/// nothing and reports what a real run would do instead.
///
/// SCF11. The reflector, analyzer and reflection-analyzer tools declared
/// `dryRun: false` because nothing read `args.dryRun`, so tom_build_base
/// refused `-n` outright — correct, but a tool that can say what it would write
/// is more useful than one that declines to answer. The preview compares with
/// what is on disk: `Would create` for a missing file, `Would update` for a
/// differing one, silence for a file that would be rewritten byte for byte.
///
/// Returns whether [path] was, or would be, changed.
Future<bool> writeOrPreview(
  String path,
  String content, {
  required bool dryRun,
}) async {
  final file = File(path);
  if (dryRun) {
    if (!file.existsSync()) {
      print('  [DRY RUN] Would create: $path');
      return true;
    }
    if (file.readAsStringSync() != content) {
      print('  [DRY RUN] Would update: $path');
      return true;
    }
    return false;
  }
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
  return true;
}
