// Smoke fixture analyzed and linted against the *real*, published
// `all_observer` package (see pubspec.yaml) - not the `fake_all_observer`
// stand-in every other fixture in this repo uses. Exercises the surface
// `AllObserverTypeChecker` and the disposal/tracking rules key on:
// Observable, Computed, effect, the workers (ever/once/debounce/interval),
// Worker/Workers, ObservableSubscription, ObservableHistory, ReactiveScope,
// ObservableFuture, ObservableStream, Observer (including withChild),
// watch(context), and the reactive collections.
import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

class SmokeWidget extends StatelessWidget {
  const SmokeWidget({super.key, required this.count, required this.items});

  final Observable<int> count;
  final ObservableList<int> items;

  @override
  Widget build(BuildContext context) {
    return Observer.withChild(
      builder: (context, child) => Column(
        children: [
          Text('${count.value}'),
          Text('${items.length}'),
          for (final item in items) Text('$item'),
          child,
        ],
      ),
      child: const Text('static'),
    );
  }
}

class WatchOnlyWidget extends StatelessWidget {
  const WatchOnlyWidget({super.key, required this.count});

  final Observable<int> count;

  @override
  Widget build(BuildContext context) {
    return Text('${count.watch(context)}');
  }
}

class SmokeController {
  SmokeController() {
    _scope.run(() {
      // Registered in `_scope`: torn down by `_scope.dispose()` in
      // `dispose()` below, without an explicit `.dispose()`/`.close()`
      // call for each of these.
      _scopedWorker = ever(count, (_) {});
      _scopedEffectDispose = effect(() => doubled.value.toString());
    });
  }

  final ReactiveScope _scope = ReactiveScope(name: 'SmokeController');

  final count = Observable(0);
  final items = <int>[1, 2, 3].obs;
  final labels = <String, int>{'a': 1}.obs;
  final tags = <String>{'x'}.obs;

  late final doubled = Computed(() => count.value * 2);
  late final disposeEffect = effect(() => doubled.value.toString());
  late final worker = debounce(
    count,
    (_) {},
    time: const Duration(milliseconds: 300),
  );
  late final onceWorker = once(count, (_) {});
  late final intervalWorker = interval(
    count,
    (_) {},
    time: const Duration(seconds: 1),
  );
  late final workers = Workers([ever(count, (_) {})]);
  late final subscription = count.listen((_) {});
  late final history = count.withHistory(limit: 10);
  late final future = ObservableFuture<int>(() async => count.value);
  late final stream = ObservableStream<int>(() => Stream.value(count.value));

  late final Worker _scopedWorker;
  late final Disposer _scopedEffectDispose;

  int readWithoutTracking() => untracked(() => count.value);

  int peekValue() => count.peek();

  void writeInBatch() {
    Observable.batch(() {
      count.value++;
      items.add(count.value);
    });
  }

  int mappedTotal() => items.map((item) => item * 2).fold(0, (a, b) => a + b);

  bool containsTag(String tag) => tags.contains(tag);

  int labelCount() => labels.keys.length;

  void dispose() {
    disposeEffect();
    worker.dispose();
    onceWorker.dispose();
    intervalWorker.dispose();
    workers.dispose();
    subscription.cancel();
    history.dispose();
    doubled.close();
    future.close();
    stream.close();
    _scope.dispose();
  }
}
