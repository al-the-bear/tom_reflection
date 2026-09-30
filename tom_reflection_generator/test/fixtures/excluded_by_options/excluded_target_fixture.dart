/// Fixture for `excluded_target_test.dart`: a generation target that this
/// package's `analysis_options.yaml` excludes from analysis.
library;

import 'package:tom_reflection/tom_reflection.dart';

class FixtureReflection extends Reflection {
  const FixtureReflection() : super(newInstanceCapability, typeCapability);
}

const fixtureReflection = FixtureReflection();

@fixtureReflection
class Excluded {
  Excluded(this.name);
  final String name;
}

void main() {}
