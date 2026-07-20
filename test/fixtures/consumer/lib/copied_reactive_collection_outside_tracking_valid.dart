import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

/// Fixture for `copied_reactive_collection_outside_tracking` — none of
/// these must be flagged; each exercises one of the rule's safety gates.
/// The original collection is *also* read inside the same tracking scope
/// — the Observer already tracks it correctly through that read.
class OriginalAlsoReadWidget extends StatelessWidget {
  const OriginalAlsoReadWidget({super.key, required this.items});
  final ObservableList<int> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.toList();
    return Observer(() => Text('${items.length}: ${visibleItems.length}'));
  }
}

/// The snapshot is reassigned elsewhere — a refreshed snapshot is not a
/// stale one.
class RefreshedSnapshotWidget extends StatelessWidget {
  const RefreshedSnapshotWidget({super.key, required this.items});
  final ObservableList<int> items;

  @override
  Widget build(BuildContext context) {
    var visibleItems = items.toList();
    visibleItems = items.toList();
    return Observer(() => Text('${visibleItems.length}'));
  }
}

/// A plain (non-reactive) `List` copied via `.toList()` is never flagged —
/// there is no reactive origin to trace back to.
class PlainListWidget extends StatelessWidget {
  const PlainListWidget({super.key, required this.items});
  final List<int> items;

  @override
  Widget build(BuildContext context) {
    final snapshot = items.toList();
    return Observer(() => Text('${snapshot.length}'));
  }
}

/// The snapshot is never read inside any tracking scope at all.
class UnusedSnapshotWidget extends StatelessWidget {
  const UnusedSnapshotWidget({super.key, required this.items});
  final ObservableList<int> items;

  @override
  Widget build(BuildContext context) {
    final snapshot = items.toList();
    // ignore: avoid_print
    print(snapshot.length);
    return Observer(() => Text('${items.length}'));
  }
}

/// Keeping the same reactive reference (`final same = items;`) is not a
/// copy at all.
class SameReferenceWidget extends StatelessWidget {
  const SameReferenceWidget({super.key, required this.items});
  final ObservableList<int> items;

  @override
  Widget build(BuildContext context) {
    final same = items;
    return Observer(() => Text('${same.length}'));
  }
}
