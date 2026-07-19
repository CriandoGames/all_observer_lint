import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

class EffectPageState extends State<StatefulWidget> {
  late final Disposer disposeEffect = effect(() {});

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
