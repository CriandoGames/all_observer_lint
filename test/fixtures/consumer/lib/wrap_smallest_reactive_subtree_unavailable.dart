import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

/// Fixture for `WrapSmallestReactiveSubtreeAssist` — cases where the
/// specialized action must stay unavailable.
class EventClosureRead extends StatelessWidget {
  const EventClosureRead({super.key, required this.count});
  final Observable<int> count;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      // The read lives inside an event handler (a non-Widget-returning
      // closure) with no Widget between it and the closure boundary — no
      // safe Widget to wrap.
      // ignore: avoid_print
      onPressed: () => print(count.value),
      child: const Text('Tap'),
    );
  }
}

class AlreadyWrapped extends StatelessWidget {
  const AlreadyWrapped({super.key, required this.count});
  final Observable<int> count;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${count.value}'));
  }
}

class NoReactiveReadPresent extends StatelessWidget {
  const NoReactiveReadPresent({super.key});

  @override
  Widget build(BuildContext context) {
    // No `.value` read anywhere near this selection: the specialized
    // assist has nothing to anchor on and must stay unavailable (the
    // permissive `Wrap with Observer` assist remains usable here).
    return const Text('Fixed');
  }
}
