/// Fixture for `test/utils/all_observer_type_checker_test.dart`: local
/// classes that share a name with a Flutter `Listenable`-family type but
/// are declared in this file, not `package:flutter/` (this file
/// deliberately does not import Flutter at all, so there is no ambiguity
/// to resolve — the local declarations are the only `ChangeNotifier`/
/// `ValueNotifier` visible here). None of these may ever be matched by
/// `isChangeNotifierType`/`isValueNotifierType`/`isFlutterListenableType`
/// — only resolved-library identity decides, never the identifier text.
/// The genuine Flutter case is covered separately by
/// `semantic_reference_index_fixture.dart`.
class ChangeNotifier {
  void addListener(void Function() listener) {}
}

class ValueNotifier<T> {
  ValueNotifier(this.value);
  T value;
}

class RealChangeNotifierUser extends ChangeNotifier {}

class RealValueNotifierUser {
  final counter = ValueNotifier<int>(0);
}
