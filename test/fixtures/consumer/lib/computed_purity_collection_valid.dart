import 'package:all_observer/all_observer.dart';

/// Fixture for the reactive-collection-mutation coverage of
/// `avoid_reactive_write_in_computed` — every `Computed` here only *reads*
/// an `ObservableList`/`ObservableMap`/`ObservableSet`; none must ever be
/// flagged.
class ReadsListInComputed {
  final items = <int>[1, 2, 3].obs;

  late final total = Computed(
    () => items.where((i) => i > 0).fold<int>(0, (a, b) => a + b),
  );
}

class ReadsMapInComputed {
  final counters = <String, int>{'a': 1}.obs;

  late final hasA = Computed(() => counters.containsKey('a'));
}

class ReadsSetInComputed {
  final tags = <String>{'a', 'b'}.obs;

  late final tagCount = Computed(() => tags.length);
}

/// A plain (non-reactive) `List` mutated inside a `Computed` must never be
/// flagged — mutation detection is gated on the target's static type being
/// `ObservableList`/`ObservableMap`/`ObservableSet`, never on the method
/// name alone.
class MutatesPlainListInComputed {
  final threshold = 1.obs;

  late final filtered = Computed(() {
    final plain = <int>[];
    plain.add(threshold.value);
    return plain;
  });
}
