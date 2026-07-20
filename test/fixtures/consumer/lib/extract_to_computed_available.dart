import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

/// Fixture for `ExtractReactiveExpressionToComputedAssist` — cases where
/// the assist must be available. Every class here is a `State` with its
/// own `dispose()`/`super.dispose()`, per the assist's "Owner lifecycle"
/// requirement.
class PriceWidget extends StatefulWidget {
  const PriceWidget({super.key});

  @override
  State<PriceWidget> createState() => _PriceWidgetState();
}

class _PriceWidgetState extends State<PriceWidget> {
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

/// Two single reads, each in its own string-interpolation section — the
/// smallest qualifying candidate is the whole interpolation, since neither
/// half alone reads two distinct values.
class NameWidget extends StatefulWidget {
  const NameWidget({super.key});

  @override
  State<NameWidget> createState() => _NameWidgetState();
}

class _NameWidgetState extends State<NameWidget> {
  final first = Observable('Ada');
  final last = Observable('Lovelace');

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${first.value} ${last.value}'));
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Name-collision case: the class already declares a `computedValue`
/// field, so the assist must fall back to `computedValue2`.
class CollisionWidget extends StatefulWidget {
  const CollisionWidget({super.key});

  @override
  State<CollisionWidget> createState() => _CollisionWidgetState();
}

class _CollisionWidgetState extends State<CollisionWidget> {
  final price = Observable(10.0);
  final quantity = Observable(2);
  final computedValue = 'reserved';

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${price.value * quantity.value}'));
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Both reads are reached only as named-argument values
/// (`SizedBox(width: width.value, height: height.value)`). The argument
/// labels themselves (`width:`/`height:`) resolve to `SizedBox`'s own
/// constructor parameters, not to anything in this class — they must not
/// be mistaken for a local/parameter dependency of the enclosing method.
class BoxWidget extends StatefulWidget {
  const BoxWidget({super.key});

  @override
  State<BoxWidget> createState() => _BoxWidgetState();
}

class _BoxWidgetState extends State<BoxWidget> {
  final width = Observable(10.0);
  final height = Observable(20.0);

  @override
  Widget build(BuildContext context) {
    return Observer(
      () => SizedBox(width: width.value, height: height.value),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
