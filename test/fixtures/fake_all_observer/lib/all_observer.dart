/// Minimal stand-in for the public surface of `all_observer` that the
/// `all_observer_lint` rules key on. Only shaped enough for the analyzer to
/// resolve the constructs the rules check (correct class names, correct
/// library, correct extension). Behavior is irrelevant: these fixtures are
/// only ever analyzed, never executed.
library all_observer;

import 'package:flutter/widgets.dart';

class CoreObservable<T> {
  CoreObservable(this._value);
  T _value;
  T get value => _value;
  set value(T next) => _value = next;
}

class Observable<T> extends CoreObservable<T> {
  Observable(super.value);
}

class CoreComputed<T> {
  CoreComputed(this._compute);
  final T Function() _compute;
  T get value => _compute();
}

class Computed<T> extends CoreComputed<T> {
  Computed(super.compute);
}

class ObservableFuture<T> extends CoreObservable<T?> {
  ObservableFuture(Future<T> Function() task) : super(null);
}

class ObservableStream<T> extends CoreObservable<T?> {
  ObservableStream(Stream<T> Function() task) : super(null);
  void dispose() {}
}

class Disposer {
  void dispose() {}
}

Disposer effect(void Function() callback) => Disposer();
Disposer ever<T>(
        CoreObservable<T> observable, void Function(T value) onChange) =>
    Disposer();
Disposer once<T>(
        CoreObservable<T> observable, void Function(T value) onChange) =>
    Disposer();
Disposer debounce<T>(
  CoreObservable<T> observable,
  void Function(T value) onChange, {
  Duration time = const Duration(milliseconds: 300),
}) =>
    Disposer();
Disposer interval<T>(
  CoreObservable<T> observable,
  void Function(T value) onChange, {
  Duration time = const Duration(seconds: 1),
}) =>
    Disposer();

void batch(void Function() callback) => callback();

extension ObservableExtension<T> on T {
  Observable<T> get obs => Observable<T>(this);
}

extension WatchExtension<T> on CoreObservable<T> {
  T watch(BuildContext context) => value;
}

class Observer extends StatelessWidget {
  const Observer(this.builder, {super.key});
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) => builder();
}
