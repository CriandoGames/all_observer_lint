import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Fixture for `ConvertChangeNotifierFieldAssist` — cases where the assist
/// must stay unavailable.

/// A *public* class — this analyzer only proves privacy makes the class
/// unreachable from other files it cannot see; it never assumes a public
/// class is safe.
class PublicController extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

/// Extends `ChangeNotifier` *indirectly*, through an intermediate class —
/// not a direct `extends ChangeNotifier`.
class _IntermediateController extends ChangeNotifier {
  void doNothing() {}
}

class _IndirectController extends _IntermediateController {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

/// A mixin is present — the project brief requires "não possui outra
/// superclass relevante", narrowed here to "no mixin at all".
mixin _LoggingMixin {}

class _MixinController extends ChangeNotifier with _LoggingMixin {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

/// `notifyListeners` is torn off and handed to another API as a callback —
/// an explicit blocking case from the project brief.
class _TearOffController extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void wireUp(void Function(VoidCallback) subscribe) {
    subscribe(notifyListeners);
  }

  void increment() {
    _count++;
    notifyListeners();
  }
}

/// Exposes `this` as a `Listenable` — an explicit blocking case from the
/// project brief (`Listenable get listenable => this;`).
class _ExposedController extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  Listenable get listenable => this;

  void increment() {
    _count++;
    notifyListeners();
  }
}

/// Passes `this` as an argument from inside its own body — an explicit
/// blocking case from the project brief (`AnimatedBuilder`-style exposure).
class _SelfPassingController extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  Widget buildWith(Widget Function(Listenable) builder) {
    return builder(this);
  }

  void increment() {
    _count++;
    notifyListeners();
  }
}

/// A *public* field — only a private field is ever considered.
class _PublicFieldController extends ChangeNotifier {
  int count = 0;

  void increment() {
    count++;
    notifyListeners();
  }
}

/// No matching getter exists for the derived public name at all.
class _NoGetterController extends ChangeNotifier {
  int _count = 0;

  void increment() {
    _count++;
    notifyListeners();
  }
}

/// The getter does more than a pure passthrough of the field.
class _ImpureGetterController extends ChangeNotifier {
  int _count = 0;
  int get count => _count + 1;

  void increment() {
    _count++;
    notifyListeners();
  }
}

/// The field/getter are referenced from *outside* the enclosing class
/// (another class in the same file) — this analyzer never attempts a
/// same-file, cross-class rewrite.
class _LeakedController extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

class _LeakedControllerReader {
  int read(_LeakedController controller) => controller.count;
}
