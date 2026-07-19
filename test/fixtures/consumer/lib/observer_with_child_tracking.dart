import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

/// Coverage for `Observer.withChild`: `observer_without_reactive_read` must
/// inspect only the `builder` callback, never the `child` argument (which
/// is built once and passed through on every rebuild, never re-tracked).
class BuilderReadsValue extends StatelessWidget {
  const BuilderReadsValue({super.key, required this.count});
  final Observable<int> count;

  @override
  Widget build(BuildContext context) {
    return Observer.withChild(
      builder: (context, child) =>
          Row(children: [Text('${count.value}'), child]),
      child: const Text('static'),
    );
  }
}

class BuilderHasNoRead extends StatelessWidget {
  const BuilderHasNoRead({super.key, required this.count});
  final Observable<int> count;

  @override
  Widget build(BuildContext context) {
    return Observer.withChild(
      builder: (context, child) => Row(children: [child]),
      child: const Text('static'),
    );
  }
}

/// The read lives only in the `child` argument, never inside `builder`
/// itself: this must still count as the builder having zero reactive
/// reads, because `child` is built once outside the Observer's tracking
/// scope and is never responsible for triggering a rebuild.
class ReadOnlyInChildArgument extends StatelessWidget {
  const ReadOnlyInChildArgument({super.key, required this.count});
  final Observable<int> count;

  @override
  Widget build(BuildContext context) {
    return Observer.withChild(
      builder: (context, child) => Row(children: [child]),
      child: Text('${count.value}'),
    );
  }
}
