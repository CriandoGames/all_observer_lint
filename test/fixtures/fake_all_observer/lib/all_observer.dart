/// Minimal stand-in for the public surface of `all_observer` that the
/// `all_observer_lint` rules key on. Only shaped enough for the analyzer to
/// resolve the constructs the rules check (correct class names, correct
/// library, correct extension). Behavior is irrelevant: these fixtures are
/// only ever analyzed, never executed.
library all_observer;

import 'dart:collection';

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

/// Modeled after the real `all_observer` shape: `ObservableList<E>` is
/// itself a `List<E>` (via `ListBase`), not a `CoreObservable` wrapper
/// around one. This matters for the analyzer: member resolution,
/// `staticType`, iteration, `[]`, `map`/`where`/spreads/collection-for all
/// need `ObservableList` to genuinely satisfy the `List` interface, the
/// same way the published package does.
class ObservableList<E> extends ListBase<E> {
  ObservableList([Iterable<E>? values]) : _values = List<E>.of(values ?? const []);

  final List<E> _values;

  @override
  int get length => _values.length;

  @override
  set length(int newLength) => _values.length = newLength;

  @override
  E operator [](int index) => _values[index];

  @override
  void operator []=(int index, E value) => _values[index] = value;

  void assign(E element) {
    _values
      ..clear()
      ..add(element);
  }

  void assignAll(Iterable<E> elements) {
    _values
      ..clear()
      ..addAll(elements);
  }

  void close() {}
}

/// Minimal fake of `ObservableMap<K, V>`, modeled on the real package's
/// `MapBase`-backed shape.
class ObservableMap<K, V> extends MapBase<K, V> {
  ObservableMap([Map<K, V>? values]) : _values = Map<K, V>.of(values ?? const {});

  final Map<K, V> _values;

  @override
  V? operator [](Object? key) => _values[key];

  @override
  void operator []=(K key, V value) => _values[key] = value;

  @override
  void clear() => _values.clear();

  @override
  Iterable<K> get keys => _values.keys;

  @override
  V? remove(Object? key) => _values.remove(key);

  void assignAll(Map<K, V> elements) {
    _values
      ..clear()
      ..addAll(elements);
  }

  void close() {}
}

/// Minimal fake of `ObservableSet<E>`, modeled on the real package's
/// `SetBase`-backed shape.
class ObservableSet<E> extends SetBase<E> {
  ObservableSet([Iterable<E>? values]) : _values = Set<E>.of(values ?? const []);

  final Set<E> _values;

  @override
  bool add(E value) => _values.add(value);

  @override
  bool contains(Object? element) => _values.contains(element);

  @override
  Iterator<E> get iterator => _values.iterator;

  @override
  int get length => _values.length;

  @override
  E? lookup(Object? element) => _values.lookup(element);

  @override
  bool remove(Object? value) => _values.remove(value);

  @override
  Set<E> toSet() => _values.toSet();

  void close() {}
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
// `time` mirrors the real `all_observer` API: it is a required named
// parameter, not optional with a default. Fixtures must always pass it
// explicitly (see requirement to keep this fake's public surface faithful
// to the published package).
Worker debounce<T>(
  CoreObservable<T> observable,
  void Function(T value) onChange, {
  required Duration time,
}) =>
    Worker();
Worker interval<T>(
  CoreObservable<T> observable,
  void Function(T value) onChange, {
  required Duration time,
}) =>
    Worker();

void batch(void Function() callback) => callback();

extension ObservableExtension<T> on T {
  Observable<T> get obs => Observable<T>(this);
}

extension ObservableListExtension<T> on List<T> {
  ObservableList<T> get obs => ObservableList<T>(this);
}

extension ObservableMapExtension<K, V> on Map<K, V> {
  ObservableMap<K, V> get obs => ObservableMap<K, V>(this);
}

extension ObservableSetExtension<E> on Set<E> {
  ObservableSet<E> get obs => ObservableSet<E>(this);
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
