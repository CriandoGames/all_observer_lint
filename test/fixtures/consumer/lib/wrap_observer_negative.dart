import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

class CounterView extends StatelessWidget {
  const CounterView({super.key, required this.count});
  final Observable<int> count;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        count.value++;
      },
      child: const Text('Increment'),
    );
  }
}

class AlreadyObserved extends StatelessWidget {
  const AlreadyObserved({super.key, required this.count});
  final Observable<int> count;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${count.value}'));
  }
}

class AlreadyWatching extends StatelessWidget {
  const AlreadyWatching({super.key, required this.count});
  final Observable<int> count;

  @override
  Widget build(BuildContext context) => Text('${count.watch(context)}');
}
