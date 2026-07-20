import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

/// Fixture for `IntroduceReactiveScopeAssist` — cases where the assist
/// must be available.

final _a = 1.obs;
final _b = 2.obs;

/// Two `Computed` fields, both disposed via `.close()` directly inside
/// `dispose()`.
class TwoComputedWidget extends StatefulWidget {
  const TwoComputedWidget({super.key});

  @override
  State<TwoComputedWidget> createState() => _TwoComputedWidgetState();
}

class _TwoComputedWidgetState extends State<TwoComputedWidget> {
  late final Computed<int> total = Computed(() => _a.value + _b.value);
  late final Computed<int> doubled = Computed(() => total.value * 2);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Text('${doubled.value}');

  @override
  void dispose() {
    total.close();
    doubled.close();
    super.dispose();
  }
}

/// A `Computed` field plus an `effect()` `Disposer` field.
class ComputedAndEffectWidget extends StatefulWidget {
  const ComputedAndEffectWidget({super.key});

  @override
  State<ComputedAndEffectWidget> createState() =>
      _ComputedAndEffectWidgetState();
}

class _ComputedAndEffectWidgetState extends State<ComputedAndEffectWidget> {
  late final Computed<int> total = Computed(() => _a.value + _b.value);
  // No explicit type annotation on purpose: `Disposer` (this field's
  // inferred type) is not exported from the real `all_observer` package's
  // public surface, so the assist must rewrite this with the underlying
  // structural type, not the alias name — see
  // `IntroduceReactiveScopeAssist._typeTextFor`.
  late final disposeEffect = effect(() {
    // ignore: avoid_print
    print(total.value);
  });

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Text('${total.value}');

  @override
  void dispose() {
    total.close();
    disposeEffect();
    super.dispose();
  }
}

/// A `Worker` field (via `ever`) plus a `Computed` field.
class WorkerAndComputedWidget extends StatefulWidget {
  const WorkerAndComputedWidget({super.key});

  @override
  State<WorkerAndComputedWidget> createState() =>
      _WorkerAndComputedWidgetState();
}

class _WorkerAndComputedWidgetState extends State<WorkerAndComputedWidget> {
  late final Computed<int> total = Computed(() => _a.value + _b.value);
  late final Worker watcher = ever(_a, (int value) {
    // ignore: avoid_print
    print(value);
  });

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Text('${total.value}');

  @override
  void dispose() {
    watcher.dispose();
    total.close();
    super.dispose();
  }
}
