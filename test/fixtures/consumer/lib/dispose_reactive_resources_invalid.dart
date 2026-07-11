import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.query});
  final Observable<String> query;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final Disposer worker = debounce(widget.query, _onSearch);

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
