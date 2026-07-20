import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

class CounterView extends StatelessWidget {
  const CounterView({super.key, required this.count});
  final Observable<int> count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Text('Total: ${count.watch(context)}'),
    );
  }
}
