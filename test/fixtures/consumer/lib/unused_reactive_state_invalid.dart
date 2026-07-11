import 'package:all_observer/all_observer.dart';

final _topLevelCount = Observable(0);

class CounterController {
  final _count = 0.obs;
  final _items = <int>[].obs;
  final _label = Computed(() => 'counter');

  void increment() {}
}
