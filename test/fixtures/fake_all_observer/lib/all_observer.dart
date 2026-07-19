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
  T peek() => _value;
  void close() {}
}

class Observable<T> extends CoreObservable<T> {
  Observable(super.value);

  static void batch(void Function() callback) => callback();
  ObservableSubscription listen(void Function(T value) listener) =>
      ObservableSubscription();
}

class ObservableList<T> extends CoreObservable<List<T>> {
  ObservableList(super.value);

  int get length => value.length;

  void clear() {}
  void add(T value) {}
  void addAll(Iterable<T> values) {}
  void assign(T value) {}
  void assignAll(Iterable<T> values) {}
}

class CoreComputed<T> {
  CoreComputed(this._compute);
  final T Function() _compute;
  T get value => _compute();
  void close() {}
}

class Computed<T> extends CoreComputed<T> {
  Computed(super.compute);
}

class ObservableFuture<T> extends CoreObservable<T?> {
  ObservableFuture(Future<T> Function() task) : super(null);
}

class ObservableStream<T> extends CoreObservable<T?> {
  ObservableStream(Stream<T> Function() task) : super(null);
}

typedef Disposer = void Function();

class Worker {
  void dispose() {}
}

class Workers {
  Workers(this.workers);
  final List<Worker> workers;
  void dispose() {}
}

class ObservableSubscription {
  void cancel() {}
}

class ObservableHistory<T> {
  ObservableHistory(this.observable, {this.limit = 100});
  final Observable<T> observable;
  final int limit;
  void dispose() {}
}

class ReactiveScope {
  T run<T>(T Function() callback) => callback();
  void dispose() {}
}

Disposer effect(void Function() callback) => () {};
Worker ever<T>(
  CoreObservable<T> observable,
  void Function(T value) onChange,
) =>
    Worker();
Worker once<T>(
  CoreObservable<T> observable,
  void Function(T value) onChange,
) =>
    Worker();
Worker debounce<T>(
  CoreObservable<T> observable,
  void Function(T value) onChange, {
  Duration time = const Duration(milliseconds: 300),
}) =>
    Worker();
Worker interval<T>(
  CoreObservable<T> observable,
  void Function(T value) onChange, {
  Duration time = const Duration(seconds: 1),
}) =>
    Worker();

void batch(void Function() callback) => callback();

extension ObservableExtension<T> on T {
  Observable<T> get obs => Observable<T>(this);
}

extension ObservableListExtension<T> on List<T> {
  ObservableList<T> get obs => ObservableList<T>(this);
}

extension WatchExtension<T> on CoreObservable<T> {
  T watch(BuildContext context) => value;
}

extension HistoryExtension<T> on Observable<T> {
  ObservableHistory<T> withHistory({int limit = 100}) =>
      ObservableHistory<T>(this, limit: limit);
}

T untracked<T>(T Function() callback) => callback();

class Observer extends StatelessWidget {
  const Observer(this.builder, {super.key});
  final Widget Function() builder;

  const Observer.withChild({
    required Widget Function(BuildContext, Widget) builder,
    required Widget child,
    super.key,
  }) : builder = _empty;

  static Widget _empty() => const SizedBox.shrink();

  @override
  Widget build(BuildContext context) => builder();
}
