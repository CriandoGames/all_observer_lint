import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

/// Fixture for `ExtractReactiveExpressionToComputedAssist` — cases where
/// the assist must stay unavailable.

/// Only one distinct reactive value is read — the brief explicitly says
/// not to suggest `Computed(() => count.value)`.
class SingleReadWidget extends StatefulWidget {
  const SingleReadWidget({super.key});

  @override
  State<SingleReadWidget> createState() => _SingleReadWidgetState();
}

class _SingleReadWidgetState extends State<SingleReadWidget> {
  final count = Observable(0);

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${count.value}'));
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Two distinct reads, but a method call (`toStringAsFixed`) sits between
/// them — "no impure call at all" blocks the whole candidate, and nothing
/// smaller has two distinct reads either.
class ImpureCallWidget extends StatefulWidget {
  const ImpureCallWidget({super.key});

  @override
  State<ImpureCallWidget> createState() => _ImpureCallWidgetState();
}

class _ImpureCallWidgetState extends State<ImpureCallWidget> {
  final price = Observable(10.0);
  final quantity = Observable(2);

  @override
  Widget build(BuildContext context) {
    return Observer(
      () => Text('${price.value.toStringAsFixed(2)} x ${quantity.value}'),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// One of the two reactive values (`quantity`) is a *local* Observable
/// declared inside `build`, not a field — a field-level `late final`
/// cannot close over it.
class LocalDependencyWidget extends StatefulWidget {
  const LocalDependencyWidget({super.key});

  @override
  State<LocalDependencyWidget> createState() => _LocalDependencyWidgetState();
}

class _LocalDependencyWidgetState extends State<LocalDependencyWidget> {
  final price = Observable(10.0);

  @override
  Widget build(BuildContext context) {
    final quantity = Observable(2);
    return Observer(() => Text('${price.value * quantity.value}'));
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// One of the two reads is reached through `widget.` — supporting this
/// correctly needs an `initState()`-based insertion, deferred for now.
class WidgetDependencyWidget extends StatefulWidget {
  const WidgetDependencyWidget({super.key, required this.price});

  final Observable<double> price;

  @override
  State<WidgetDependencyWidget> createState() =>
      _WidgetDependencyWidgetState();
}

class _WidgetDependencyWidgetState extends State<WidgetDependencyWidget> {
  final quantity = Observable(2);

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${widget.price.value * quantity.value}'));
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// The candidate expression also references `BuildContext`.
class ContextAccessWidget extends StatefulWidget {
  const ContextAccessWidget({super.key});

  @override
  State<ContextAccessWidget> createState() => _ContextAccessWidgetState();
}

class _ContextAccessWidgetState extends State<ContextAccessWidget> {
  final price = Observable(10.0);
  final quantity = Observable(2);

  @override
  Widget build(BuildContext context) {
    return Observer(
      () => Text('${context.mounted ? price.value : quantity.value}'),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// A `StatelessWidget` has no `dispose()` at all — a field there would be
/// recreated every rebuild, so the assist must stay unavailable rather
/// than reproduce that bug class.
class StatelessPriceWidget extends StatelessWidget {
  const StatelessPriceWidget({
    super.key,
    required this.price,
    required this.quantity,
  });

  final Observable<double> price;
  final Observable<int> quantity;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${price.value * quantity.value}'));
  }
}
