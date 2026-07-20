import 'package:flutter/material.dart';

/// Fixture for `ConvertValueNotifierAssist` — cases where the assist must
/// be available.
class CounterWidget extends StatefulWidget {
  const CounterWidget({super.key});

  @override
  State<CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget> {
  final ValueNotifier<int> _count = ValueNotifier(0);

  void _increment() => _count.value++;

  @override
  Widget build(BuildContext context) => Text('${_count.value}');

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }
}

/// Inferred declaration type (no explicit `ValueNotifier<bool>`), and no
/// `.dispose()` call anywhere — the assist must still convert the
/// declaration; there's simply nothing to rewrite to `.close()`.
class FlagWidget extends StatefulWidget {
  const FlagWidget({super.key});

  @override
  State<FlagWidget> createState() => _FlagWidgetState();
}

class _FlagWidgetState extends State<FlagWidget> {
  final _flag = ValueNotifier(false);

  void _toggle() => _flag.value = !_flag.value;

  @override
  Widget build(BuildContext context) => Text('${_flag.value}');
}

/// A single, balanced `addListener`/`removeListener` pair — both calls
/// must be left completely untouched by the conversion (see
/// `ValueNotifierMigrationAnalyzer`, "Why listeners need no rewrite").
class ScoreWidget extends StatefulWidget {
  const ScoreWidget({super.key});

  @override
  State<ScoreWidget> createState() => _ScoreWidgetState();
}

class _ScoreWidgetState extends State<ScoreWidget> {
  final ValueNotifier<int> _score = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _score.addListener(_onScoreChanged);
  }

  void _onScoreChanged() {
    // ignore: avoid_print
    print(_score.value);
  }

  @override
  Widget build(BuildContext context) => Text('${_score.value}');

  @override
  void dispose() {
    _score.removeListener(_onScoreChanged);
    _score.dispose();
    super.dispose();
  }
}
