// This file intentionally mixes flagged and fixed versions of the same
// widget side by side, so running `dart run custom_lint` here shows the
// diagnostics documented in `documentation/en/rules/`.
//
// Run:
//   cd example
//   flutter pub get
//   dart run custom_lint

import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: CounterPage());
  }
}

// -- avoid_reactive_creation_in_build -----------------------------------

// Flagged: `count` is recreated (and its previous value lost) every time
// this widget rebuilds.
class CounterBadExample extends StatelessWidget {
  const CounterBadExample({super.key});

  @override
  Widget build(BuildContext context) {
    final count = 0.obs; // avoid_reactive_creation_in_build
    return Text('${count.value}');
  }
}

// Fixed: the Observable lives in State, created exactly once.
class CounterGoodExample extends StatefulWidget {
  const CounterGoodExample({super.key});

  @override
  State<CounterGoodExample> createState() => _CounterGoodExampleState();
}

class _CounterGoodExampleState extends State<CounterGoodExample> {
  final count = 0.obs;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${count.value}'));
  }
}

// -- dispose_reactive_resources ------------------------------------------

class SearchBadExample extends StatefulWidget {
  const SearchBadExample({super.key, required this.query});
  final Observable<String> query;

  @override
  State<SearchBadExample> createState() => _SearchBadExampleState();
}

class _SearchBadExampleState extends State<SearchBadExample> {
  late final Worker worker = debounce(
    widget.query,
    (value) {},
    time: const Duration(milliseconds: 300),
  );

  @override
  void dispose() {
    // Flagged: `worker` is never disposed.
    super.dispose(); // dispose_reactive_resources
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class SearchGoodExample extends StatefulWidget {
  const SearchGoodExample({super.key, required this.query});
  final Observable<String> query;

  @override
  State<SearchGoodExample> createState() => _SearchGoodExampleState();
}

class _SearchGoodExampleState extends State<SearchGoodExample> {
  late final Worker worker = debounce(
    widget.query,
    (value) {},
    time: const Duration(milliseconds: 300),
  );

  @override
  void dispose() {
    worker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// -- Full example page combining a few observables --------------------

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  final count = 0.obs;
  late final Computed<String> label = Computed(() => 'Count: ${count.value}');

  void _increment() => count.value++;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Observer(() => Text(label.value))),
      floatingActionButton: FloatingActionButton(
        onPressed: _increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
