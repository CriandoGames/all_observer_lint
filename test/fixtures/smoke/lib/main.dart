import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

class SmokeWidget extends StatelessWidget {
  const SmokeWidget({super.key, required this.count});

  final Observable<int> count;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${count.value}'));
  }
}

class SmokeController {
  final count = Observable(0);
  late final doubled = Computed(() => count.value * 2);
  late final disposeEffect = effect(() => doubled.value.toString());

  void dispose() {
    disposeEffect();
    doubled.close();
  }
}
