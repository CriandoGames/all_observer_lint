import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

class ReadOnlyObserverWidget extends StatelessWidget {
  const ReadOnlyObserverWidget({super.key, required this.counter});
  final Observable<int> counter;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${counter.value}'));
  }
}

class DeferredWriteObserverWidget extends StatelessWidget {
  const DeferredWriteObserverWidget({super.key, required this.counter});
  final Observable<int> counter;

  @override
  Widget build(BuildContext context) {
    return Observer(() {
      return ElevatedButton(
        // Write happens only when tapped, not while Observer is building.
        onPressed: () => counter.value = 0,
        child: Text('${counter.value}'),
      );
    });
  }
}
