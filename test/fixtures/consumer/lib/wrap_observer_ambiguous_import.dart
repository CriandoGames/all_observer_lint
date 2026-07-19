import 'package:another_package/observer.dart';
import 'package:flutter/widgets.dart';

import 'reactive_model.dart';

/// `package:another_package/observer.dart` is imported unprefixed and also
/// exposes a class named `Observer`. There is no `all_observer` import in
/// this file at all yet, so adding one unprefixed (the old default) would
/// make every future `Observer(...)` reference in this file ambiguous
/// between the two libraries. The assist must add a uniquely-prefixed
/// import instead.
class CounterView extends StatelessWidget {
  const CounterView({super.key, required this.model});
  final ReactiveModel model;

  @override
  Widget build(BuildContext context) {
    return Text('Total: ${model.count.value}');
  }
}
