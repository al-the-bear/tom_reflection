/// Fixture for `bounded_generic_constructor_test.dart`: reflected classes whose
/// type parameters carry bounds, each with a constructor the generator emits a
/// closure for.
library;

import 'package:tom_reflection/tom_reflection.dart';

class FixtureReflection extends Reflection {
  const FixtureReflection() : super(newInstanceCapability, typeCapability);
}

const fixtureReflection = FixtureReflection();

enum Colour { red, green }

/// A bound on a core type: the shape of Flutter's `NumRange<T extends num>`.
@fixtureReflection
class NumRange<T extends num> {
  NumRange(this.low, this.high);
  final T low;
  final T high;
}

/// A bound on `Enum`: the shape of `TomObservableEnum<E extends Enum>`.
@fixtureReflection
class EnumBox<E extends Enum> {
  EnumBox(this.value, {this.fallback});
  final E value;
  final E? fallback;
}

/// A generic bound, rendered with its own type argument.
@fixtureReflection
class Numbers<T extends List<num>> {
  Numbers.of(this.values);
  final T values;
}

/// Two parameters, one bounded and one not.
@fixtureReflection
class Keyed<K extends Object, V> {
  Keyed(this.key, this.value);
  final K key;
  final V value;
}

/// No bound at all: the control, emitted as it always was.
@fixtureReflection
class Plain<T> {
  Plain(this.value);
  final T value;
}

void main() {}
