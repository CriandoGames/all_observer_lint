import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

/// Fixture for `ExtractReactiveExpressionToComputedAssist` — a local
/// top-level `Computed` homonym must never be confused with the real
/// `all_observer` `Computed`. The assist must fall back to a uniquely
/// prefixed import (`allObserver.Computed`) instead of emitting a bare
/// `Computed` reference, which would resolve to this local class.
class Computed {
  const Computed();
}

class HomonymWidget extends StatefulWidget {
  const HomonymWidget({super.key});

  @override
  State<HomonymWidget> createState() => _HomonymWidgetState();
}

class _HomonymWidgetState extends State<HomonymWidget> {
  final price = Observable(10.0);
  final quantity = Observable(2);

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${price.value * quantity.value}'));
  }

  @override
  void dispose() {
    super.dispose();
  }
}
