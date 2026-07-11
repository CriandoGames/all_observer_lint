import 'package:all_observer/all_observer.dart';

final _topLevelCount = Observable(0);

int readTopLevelCount() => _topLevelCount.value;

class CounterController {
  final _count = 0.obs;
  final _items = <int>[].obs;
  final _label = Computed(() => 'counter');
  final publicCount = 0.obs;

  void increment() {
    _count.value++;
  }

  void replaceItems(List<int> items) {
    this._items.assignAll(items);
  }

  String get label => _label.value;
}

class LocalStateIsIgnored {
  void createLocalState() {
    final count = 0.obs;
    count.value++;
  }
}
