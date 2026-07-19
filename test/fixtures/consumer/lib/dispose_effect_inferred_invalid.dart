import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

/// The common form: no explicit `Disposer` annotation, the type is inferred
/// from `effect()`'s return type. Must be flagged the same way as the
/// explicitly-annotated case.
class EffectState extends State<StatefulWidget> {
  late final disposeEffect = effect(() {});

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
