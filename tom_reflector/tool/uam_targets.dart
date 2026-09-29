/// The workspace root and the UAM entry points the `tool/*uam*` scripts share.
///
/// The UAM stack — `tom_uam_server` and every `tom_*` package it reaches — is
/// the largest analysis target in the workspace, which is what makes it the
/// useful one: a tool that copes with it copes with anything else here. Four
/// scripts analyse it, so the list lives once, here.
library;

import 'workspace.dart';

/// The UAM server's entry point, which reaches the rest of the stack.
String get uamServerEntryPoint =>
    '$workspaceRoot/tom_uam/tom_uam_server/bin/aa_server_start.dart';

/// Every entry point of the UAM analysis: the server and each `tom_*` package
/// whose annotations it carries.
List<String> get uamEntryPoints => [
  uamServerEntryPoint,
  '$workspaceRoot/tom_uam/tom_uam_codespec/lib/tom_uam_codespec.dart',
  '$workspaceRoot/tom_ai/core/tom_core_kernel/lib/tom_core_kernel.dart',
  '$workspaceRoot/tom_ai/reflection/tom_reflection/lib/tom_reflection.dart',
  '$workspaceRoot/tom_ai/basics/tom_basics/lib/tom_basics.dart',
  '$workspaceRoot/tom_ai/basics/tom_crypto/lib/tom_crypto.dart',
];
