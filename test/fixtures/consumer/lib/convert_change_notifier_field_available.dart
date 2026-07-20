import 'package:flutter/foundation.dart';

/// Fixture for `ConvertChangeNotifierFieldAssist` — cases where the assist
/// must be available.

/// Explicit type, a single `notifyListeners()` call left untouched (see
/// `ChangeNotifierFieldMigrationAnalyzer`, "Scope (first version)").
class _CounterController extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

/// Inferred type (no explicit `bool` annotation on the field, just `var`).
class _FlagController extends ChangeNotifier {
  var _enabled = false;
  bool get enabled => _enabled;

  void toggle() {
    _enabled = !_enabled;
    notifyListeners();
  }
}

/// Explicit `num` type, preserved as `Observable<num>` rather than the
/// narrower inferred `int`. The getter is also read from `toString()`,
/// which must be rewritten to `.value` too.
class _ScoreController extends ChangeNotifier {
  num _score = 0;
  num get score => _score;

  void add(num amount) {
    _score += amount;
    notifyListeners();
  }

  @override
  String toString() => 'score: $score';
}
