import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

/// Inferred `Disposer` type, properly disposed: must not be flagged.
class EffectState extends State<StatefulWidget> {
  late final disposeEffect = effect(() {});

  @override
  void dispose() {
    disposeEffect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Explicit structural function type instead of the `Disposer` alias. The
/// initializer still resolves to `effect(...)` and the declared type is
/// invocable with no required arguments, so this is also recognized and,
/// once disposed, must not be flagged.
class ExplicitFunctionTypeState extends State<StatefulWidget> {
  final void Function() disposeEffect = effect(() {});

  @override
  void dispose() {
    disposeEffect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// A field whose declared type is not invocable (e.g. `Object`) must never
/// receive a `field();` fix, even though its initializer is `effect(...)`.
/// The rule intentionally stays silent here rather than risk generating
/// invalid code.
class UnsafeTypeState extends State<StatefulWidget> {
  final Object disposeEffect = effect(() {});

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
