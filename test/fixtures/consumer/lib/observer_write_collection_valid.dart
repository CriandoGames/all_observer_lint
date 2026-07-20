import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

/// Fixture for the reactive-collection-mutation coverage of
/// `avoid_observable_write_during_observer_build` — reads are never
/// flagged, and a mutation deferred to an event-handler closure declared
/// inside the `Observer` (not executed while the `Observer` itself is
/// building) is never flagged either, mirroring
/// `observer_write_valid.dart`'s `DeferredWriteObserverWidget`.
class ReadsListDuringObserverBuild extends StatelessWidget {
  const ReadsListDuringObserverBuild({super.key, required this.items});
  final ObservableList<int> items;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${items.length} items: ${items.contains(1)}'));
  }
}

class DeferredListMutationObserverWidget extends StatelessWidget {
  const DeferredListMutationObserverWidget({
    super.key,
    required this.items,
  });
  final ObservableList<int> items;

  @override
  Widget build(BuildContext context) {
    return Observer(() {
      return ElevatedButton(
        // Mutation happens only when tapped, not while Observer is building.
        onPressed: () => items.add(0),
        child: Text('${items.length}'),
      );
    });
  }
}
