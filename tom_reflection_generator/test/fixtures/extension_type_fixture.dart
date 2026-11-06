/// Fixture for `extension_type_test.dart`: a reflected class whose fields are
/// a `List<String>`, a `List<Item>` and an extension type over `String`, under
/// a reflector that quantifies over type annotations (as `TomReflector` does),
/// so the extension type is reached through the field's type annotation.
library;

import 'package:tom_reflection/tom_reflection.dart';

class FixtureReflection extends Reflection {
  const FixtureReflection()
    : super.fromList(const [
        invokingCapability,
        typingCapability,
        typeRelationsCapability,
        reflectedTypeCapability,
        typeAnnotationDeepQuantifyCapability,
        typeAnnotationQuantifyCapability,
      ]);
}

const fixtureReflection = FixtureReflection();

/// An extension type over `String`: at run time its values are `String`s.
extension type Label(String value) implements String {}

/// An extension type over a reflected class.
extension type ItemRef(Item item) implements Item {}

@fixtureReflection
class Item {
  String name = '';
}

@fixtureReflection
class Holder {
  List<String> tags = [];
  List<Item> items = [];
  Label label = Label('x');
  ItemRef? ref;
  Label rename(Label other) => other;
}

/// The entry point the generator requires of a target.
void main() {}
