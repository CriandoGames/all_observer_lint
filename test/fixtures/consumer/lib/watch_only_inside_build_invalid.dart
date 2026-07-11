import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

class CounterPanel extends StatefulWidget {
  const CounterPanel({super.key, required this.counter});
  final Observable<int> counter;

  @override
  State<CounterPanel> createState() => _CounterPanelState();
}

class _CounterPanelState extends State<CounterPanel> {
  // Not the build method: `context` here is State's own context getter,
  // not tied to a rebuild the way build(BuildContext context) is.
  void submit() {
    final value = widget.counter.watch(context);
    // ignore: avoid_print
    print(value);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: submit, child: const Text('submit'));
  }
}
