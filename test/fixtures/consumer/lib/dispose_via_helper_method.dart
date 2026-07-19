import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

/// Disposal delegated to a same-class, zero-argument helper method must be
/// recognized: `dispose_reactive_resources` follows a bare/`this.` call to
/// such a helper and searches its body too, not just `dispose()` itself.
class DisposesThroughHelper extends State<StatefulWidget> {
  late final Worker worker = debounce(
    count,
    (_) {},
    time: const Duration(milliseconds: 300),
  );
  final count = Observable(0);

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }

  void _disposeResources() {
    worker.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Same as above, but through two levels of helper indirection.
class DisposesThroughNestedHelper extends State<StatefulWidget> {
  late final Worker worker = debounce(
    count,
    (_) {},
    time: const Duration(milliseconds: 300),
  );
  final count = Observable(0);

  @override
  void dispose() {
    this._disposeEverything();
    super.dispose();
  }

  void _disposeEverything() {
    _disposeWorker();
  }

  void _disposeWorker() {
    worker.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// A helper that takes an argument is deliberately NOT followed (narrow,
/// same-class + zero-argument only), so a field only disposed inside one
/// must still be flagged rather than risk following an arbitrary call
/// graph.
class HelperWithArgumentNotFollowed extends State<StatefulWidget> {
  late final Worker worker = debounce(
    count,
    (_) {},
    time: const Duration(milliseconds: 300),
  );
  final count = Observable(0);

  @override
  void dispose() {
    _disposeWith(worker);
    super.dispose();
  }

  void _disposeWith(Worker target) {
    target.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
