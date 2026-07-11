import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

class EffectInBuildWidget extends StatelessWidget {
  const EffectInBuildWidget({super.key, required this.counter});
  final Observable<int> counter;

  @override
  Widget build(BuildContext context) {
    effect(() {
      // ignore: avoid_print
      print(counter.value);
    });
    return Text('${counter.value}');
  }
}

class EverInBuildWidget extends StatelessWidget {
  const EverInBuildWidget({super.key, required this.counter});
  final Observable<int> counter;

  @override
  Widget build(BuildContext context) {
    ever(counter, (value) {});
    return Text('${counter.value}');
  }
}

class DebounceInObserverCallbackWidget extends StatelessWidget {
  const DebounceInObserverCallbackWidget({super.key, required this.query});
  final Observable<String> query;

  @override
  Widget build(BuildContext context) {
    return Observer(() {
      debounce(query, (value) {});
      return Text(query.value);
    });
  }
}
