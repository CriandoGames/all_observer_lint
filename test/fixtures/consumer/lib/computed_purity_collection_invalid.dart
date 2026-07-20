import 'package:all_observer/all_observer.dart';

/// Fixture for the reactive-collection-mutation coverage of
/// `avoid_reactive_write_in_computed` (see `test/rules/computed_purity_test.dart`).
/// Every `Computed` here mutates an `ObservableList`/`ObservableMap`/
/// `ObservableSet` inside its own derivation callback — each must be
/// flagged by `ReactiveWriteDetector`, exactly like a `.value` write.
class MutatesListInComputed {
  final items = <int>[1, 2, 3].obs;

  late final total = Computed(() {
    items.add(0); // mutation (1)
    return items.length;
  });
}

class ReplacesListInComputed {
  final items = <int>[1, 2, 3].obs;

  late final total = Computed(() {
    items.assignAll([1, 2]); // replacement (1)
    return items.length;
  });
}

class MutatesMapInComputed {
  final counters = <String, int>{}.obs;

  late final total = Computed(() {
    counters['a'] = 1; // index-assignment mutation (1)
    return counters.length;
  });
}

class MutatesSetInComputed {
  final tags = <String>{}.obs;

  late final total = Computed(() {
    tags.add('a'); // mutation (1)
    return tags.length;
  });
}
