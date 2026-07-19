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

  void _onSearch(String value) {}

  @override
  void initState() {
    super.initState();
    final unrelatedEffect = effect(() {});
    unrelatedEffect();
  }

  @override
  void dispose() {
    worker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // A worker created only in response to a tap, not every rebuild.
        ever(widget.query, (value) {});
      },
      child: const Text('search'),
    );
  }
}
