import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.query});
  final Observable<String> query;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final Worker worker = debounce(
    widget.query,
    _onSearch,
    time: const Duration(milliseconds: 300),
  );
  late final Disposer disposeEffect = effect(() {});

  void _onSearch(String value) {}

  @override
  void dispose() {
    worker.dispose();
    disposeEffect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// No dispose() method at all: the rule requires an owning lifecycle before
// it can claim a resource was left undisposed, so this is not flagged
// (ownership is ambiguous without a dispose() to check against).
class PlainHolder {
  late final Disposer disposeEffect = effect(() {});
}

class AllKindsState extends State<StatefulWidget> {
  final source = Observable(0);
  final plainObservableIsNotAutomated = Observable(1);
  late final Computed<int> computed = Computed(() => source.value * 2);
  late final ObservableHistory<int> history = source.withHistory();
  late final ObservableSubscription subscription = source.listen((_) {});
  late final ReactiveScope scope = ReactiveScope();
  late final ObservableFuture<int> future = ObservableFuture(
    () async => source.value,
  );
  late final ObservableStream<int> stream = ObservableStream(
    () => Stream.value(source.value),
  );
  late final Workers workers = Workers([ever(source, (_) {})]);

  @override
  void dispose() {
    this.computed.close();
    history.dispose();
    this.subscription.cancel();
    scope.dispose();
    future.close();
    this.stream.close();
    workers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
