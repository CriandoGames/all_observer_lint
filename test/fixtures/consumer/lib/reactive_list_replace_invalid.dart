import 'package:all_observer/all_observer.dart';

class ReplaceWithAddAll {
  final items = <int>[].obs;

  void replace(List<int> nextItems) {
    items.clear();
    items.addAll(nextItems);
  }
}

class ReplaceWithSingleItem {
  final items = <int>[].obs;

  void replace(int item) {
    items.clear();
    items.add(item);
  }
}

class ReplaceThisField {
  final items = <int>[].obs;

  void replace(List<int> nextItems) {
    this.items.clear();
    this.items.addAll(nextItems);
  }
}
