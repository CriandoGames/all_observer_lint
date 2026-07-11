import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

class CounterText extends StatelessWidget {
  const CounterText({super.key, required this.counter});
  final Observable<int> counter;

  @override
  Widget build(BuildContext context) {
    return Text('${counter.watch(context)}');
  }
}

class CounterObserverText extends StatelessWidget {
  const CounterObserverText({super.key, required this.counter});
  final Observable<int> counter;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${counter.value}'));
  }
}

class AmbiguousHelperWidget extends StatelessWidget {
  const AmbiguousHelperWidget({super.key, required this.counter});
  final Observable<int> counter;

  // Accepts BuildContext but is not named `build`: could legitimately only
  // ever be called from inside a build method, so the rule stays silent.
  Widget describe(BuildContext context) {
    return Text('${counter.watch(context)}');
  }

  @override
  Widget build(BuildContext context) => describe(context);
}
