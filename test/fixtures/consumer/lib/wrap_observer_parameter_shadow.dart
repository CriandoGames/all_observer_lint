import 'package:all_observer/all_observer.dart';
import 'package:another_package/observer.dart' as allObserver;
import 'package:flutter/widgets.dart';

/// `allObserver` is already used as the prefix for an unrelated import in
/// this file, and a local variable named `Observer` makes the bare name
/// unsafe at the selection point. The assist must both (a) avoid reusing
/// the bare `Observer` name and (b) avoid reusing the already-taken
/// `allObserver` prefix, generating `allObserver2` instead.
class CounterView extends StatelessWidget {
  const CounterView({super.key, required this.count});
  final Observable<int> count;

  allObserver.Observer get unrelated => const allObserver.Observer();

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final Observer = count.value;
    return Text('Total: ${count.value}');
  }
}
