import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

/// Fixture for `copied_reactive_collection_outside_tracking` — every class
/// here copies a reactive collection into a plain snapshot before an
/// `Observer`, and only the snapshot (never the original) is read inside
/// the `Observer` builder. Each must be flagged.
class VisibleItemsWidget extends StatelessWidget {
  const VisibleItemsWidget({super.key, required this.items});
  final ObservableList<int> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.toList();
    return Observer(
      () => Column(children: visibleItems.map((i) => Text('$i')).toList()),
    );
  }
}

class FilteredTagsWidget extends StatelessWidget {
  const FilteredTagsWidget({super.key, required this.tags});
  final ObservableSet<String> tags;

  @override
  Widget build(BuildContext context) {
    final snapshot = tags.toSet();
    return Observer(() => Text('${snapshot.length}'));
  }
}

class MapKeysWidget extends StatelessWidget {
  const MapKeysWidget({super.key, required this.counters});
  final ObservableMap<String, int> counters;

  @override
  Widget build(BuildContext context) {
    final keySnapshot = counters.keys.toList();
    return Observer(() => Text('${keySnapshot.length}'));
  }
}
