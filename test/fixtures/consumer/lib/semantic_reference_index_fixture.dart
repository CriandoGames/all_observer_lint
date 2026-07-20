import 'package:all_observer/all_observer.dart';
import 'package:flutter/foundation.dart';

/// Fixture for `test/utils/semantic_reference_index_test.dart`.
///
/// Listener registration/removal is exercised through plain Flutter
/// `ValueNotifier`/`ChangeNotifier` targets rather than through
/// `Observable`/`Computed`: `test/fixtures/fake_all_observer` does not yet
/// model `Observable`/`Computed` implementing `ValueListenable`'s
/// `addListener`/`removeListener` (the real package does — see
/// `documentation/backlog.md`), so a fixture that called
/// `_count.addListener(...)` would not even compile against the fake today.
/// The listener-collection code path exercised here
/// (`AllObserverTypeChecker.isFlutterListenableType`) is identical either
/// way — only the *target*'s declared type differs.
class _LegacyCounter extends ChangeNotifier {
  int value = 0;
}

class SemanticIndexFixture {
  final Observable<int> _count = Observable(0);
  final ObservableList<int> _items = ObservableList<int>([]);
  final ValueNotifier<int> _legacyCount = ValueNotifier<int>(0);
  final _LegacyCounter _legacyCounter = _LegacyCounter();
  final int _unused = 0;

  void _onChanged() {}

  SemanticIndexFixture() {
    _legacyCount.addListener(_onChanged);
    _legacyCounter.addListener(_onChanged);
  }

  void read() {
    // ignore: unused_local_variable
    final value = _count.value;
    // ignore: unused_local_variable
    final hasItem = _items.contains(1);
  }

  void mutate() {
    _count.value = 1;
    _items.add(1);
  }

  void teardown() {
    _legacyCount.removeListener(_onChanged);
    _legacyCounter.removeListener(_onChanged);
  }
}
