import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

class EmptyScopes extends StatelessWidget {
  EmptyScopes({super.key});

  late final noDependency = Computed(() => 42);
  late final disposeEffect = effect(() {
    final answer = 42;
    answer.toString();
  });

  @override
  Widget build(BuildContext context) => Observer(() => const SizedBox());
}
