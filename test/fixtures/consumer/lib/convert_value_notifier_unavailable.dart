import 'package:flutter/material.dart';

/// Fixture for `ConvertValueNotifierAssist` — cases where the assist must
/// stay unavailable.

/// A *public* field is never even considered — only private fields/
/// top-level declarations are indexed.
class PublicFieldWidget extends StatefulWidget {
  const PublicFieldWidget({super.key});

  @override
  State<PublicFieldWidget> createState() => _PublicFieldWidgetState();
}

class _PublicFieldWidgetState extends State<PublicFieldWidget> {
  final ValueNotifier<int> count = ValueNotifier(0);

  @override
  Widget build(BuildContext context) => Text('${count.value}');

  @override
  void dispose() {
    count.dispose();
    super.dispose();
  }
}

/// The field is passed as an argument to `ValueListenableBuilder` — a
/// `ValueListenable` consumer, blocked per "bloqueio de consumidores
/// incompatíveis".
class BuilderConsumerWidget extends StatefulWidget {
  const BuilderConsumerWidget({super.key});

  @override
  State<BuilderConsumerWidget> createState() => _BuilderConsumerWidgetState();
}

class _BuilderConsumerWidgetState extends State<BuilderConsumerWidget> {
  final ValueNotifier<int> _count = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _count,
      builder: (context, value, child) => Text('$value'),
    );
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }
}

/// `addListener` is called with no matching `removeListener` anywhere —
/// an unbalanced pair.
class UnbalancedListenerWidget extends StatefulWidget {
  const UnbalancedListenerWidget({super.key});

  @override
  State<UnbalancedListenerWidget> createState() =>
      _UnbalancedListenerWidgetState();
}

class _UnbalancedListenerWidgetState extends State<UnbalancedListenerWidget> {
  final ValueNotifier<int> _count = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _count.addListener(_onChanged);
  }

  void _onChanged() {
    // ignore: avoid_print
    print(_count.value);
  }

  @override
  Widget build(BuildContext context) => Text('${_count.value}');

  @override
  void dispose() {
    // No removeListener call at all — unbalanced.
    _count.dispose();
    super.dispose();
  }
}

/// The initializer is not a direct `ValueNotifier(...)` construction — it
/// is reached through a helper function instead.
ValueNotifier<int> _makeCounter() => ValueNotifier(0);

class IndirectInitializerWidget extends StatefulWidget {
  const IndirectInitializerWidget({super.key});

  @override
  State<IndirectInitializerWidget> createState() =>
      _IndirectInitializerWidgetState();
}

class _IndirectInitializerWidgetState
    extends State<IndirectInitializerWidget> {
  final ValueNotifier<int> _count = _makeCounter();

  @override
  Widget build(BuildContext context) => Text('${_count.value}');

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }
}
