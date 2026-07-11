import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

class ClampingObserverWidget extends StatelessWidget {
  const ClampingObserverWidget({super.key, required this.counter});
  final Observable<int> counter;

  @override
  Widget build(BuildContext context) {
    return Observer(() {
      if (counter.value < 0) {
        counter.value = 0;
      }
      return Text('${counter.value}');
    });
  }
}

class IncrementingObserverWidget extends StatelessWidget {
  const IncrementingObserverWidget({super.key, required this.counter});
  final Observable<int> counter;

  @override
  Widget build(BuildContext context) {
    return Observer(() {
      counter.value++;
      return Text('${counter.value}');
    });
  }
}
