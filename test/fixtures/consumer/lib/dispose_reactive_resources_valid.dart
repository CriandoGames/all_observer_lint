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
    worker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// No dispose() method at all: the rule requires an owning lifecycle before
// it can claim a resource was left undisposed, so this is not flagged
// (ownership is ambiguous without a dispose() to check against).
class PlainHolder {
  late final Disposer worker = effect(() {});
}
