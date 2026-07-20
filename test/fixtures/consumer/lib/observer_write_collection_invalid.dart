import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

/// Fixture for the reactive-collection-mutation coverage of
/// `avoid_observable_write_during_observer_build`
/// (see `test/rules/avoid_observable_write_during_observer_build_test.dart`).
/// Each `Observer` here mutates a reactive collection directly in its own
/// build callback — must be flagged.
class MutatesListDuringObserverBuild extends StatelessWidget {
  const MutatesListDuringObserverBuild({super.key, required this.items});
  final ObservableList<int> items;

  @override
  Widget build(BuildContext context) {
    return Observer(() {
      items.add(0); // mutation (1)
      return Text('${items.length}');
    });
  }
}

class ReplacesListDuringObserverBuild extends StatelessWidget {
  const ReplacesListDuringObserverBuild({super.key, required this.items});
  final ObservableList<int> items;

  @override
  Widget build(BuildContext context) {
    return Observer(() {
      items.assignAll([1, 2]); // replacement (1)
      return Text('${items.length}');
    });
  }
}
