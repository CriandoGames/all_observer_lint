import 'package:flutter/widgets.dart';

import 'reactive_model.dart';

class CounterView extends StatelessWidget {
  const CounterView({super.key, required this.model});
  final ReactiveModel model;

  @override
  Widget build(BuildContext context) {
    return Text('Total: ${model.count.value}');
  }
}
