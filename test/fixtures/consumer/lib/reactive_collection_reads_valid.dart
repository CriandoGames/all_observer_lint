import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

/// Regression coverage for the *_without_reactive_read rules: a tracking
/// scope that only iterates/queries a reactive collection (rather than
/// reading `.length`/`[i]`/`.isEmpty` directly) must not be flagged as
/// having proven zero reactive reads. `ObservableList`/`ObservableMap`
/// implement these operations on top of `length`/`[]`, which is what
/// actually registers the dependency at runtime; this fixture exercises
/// the statically-recognized subset of that surface.
class CollectionReadScopes extends StatelessWidget {
  CollectionReadScopes({super.key});

  final items = <int>[1, 2, 3].obs;
  final labels = <String, int>{'a': 1}.obs;

  late final mapped = Computed(() => items.map((item) => item * 2).toList());
  late final filtered = Computed(
    () => items.where((item) => item > 0).length,
  );
  late final containsThree = Computed(() => items.contains(3));
  late final joined = Computed(() => items.join(', '));
  late final keyCount = Computed(() => labels.keys.length);

  @override
  Widget build(BuildContext context) {
    return Observer(
      () => Column(
        children: [
          for (final item in items) Text('$item'),
          ...items.map((item) => Text('spread $item')),
        ],
      ),
    );
  }
}
