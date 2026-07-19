import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.query});
  final Observable<String> query;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final Worker worker = debounce(widget.query, _onSearch);
  late final Disposer disposeEffect = effect(() {});

  void _onSearch(String value) {}

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class StreamPage extends StatefulWidget {
  const StreamPage({super.key});

  @override
  State<StreamPage> createState() => _StreamPageState();
}

class _StreamPageState extends State<StreamPage> {
  late final ObservableStream<int> ticks = ObservableStream(_tickStream);

  Stream<int> _tickStream() => const Stream.empty();

  @override
  void dispose() {
    // ticks is never disposed.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class AllKindsState extends State<StatefulWidget> {
  final source = Observable(0);
  late final Computed<int> computed = Computed(() => source.value * 2);
  late final ObservableHistory<int> history = source.withHistory();
  late final ObservableSubscription subscription = source.listen((_) {});
  late final ReactiveScope scope = ReactiveScope();
  late final ObservableFuture<int> future = ObservableFuture(
    () async => source.value,
  );
  late final Workers workers = Workers([ever(source, (_) {})]);

  @override
  void dispose() {
    final other = _SameNames();
    other.disposeEffect();
    other.computed.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _SameNames {
  void disposeEffect() {}
  final computed = Observable(0);
}
