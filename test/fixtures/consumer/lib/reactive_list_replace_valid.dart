import 'package:all_observer/all_observer.dart';

class UsesAssignAll {
  final items = <int>[].obs;

  void replace(List<int> nextItems) {
    items.assignAll(nextItems);
  }
}

class UsesAssign {
  final items = <int>[].obs;

  void replace(int item) {
    items.assign(item);
  }
}

class ClearOnly {
  final items = <int>[].obs;

  void clear() {
    items.clear();
  }
}

class DifferentLists {
  final first = <int>[].obs;
  final second = <int>[].obs;

  void replace(List<int> nextItems) {
    first.clear();
    second.addAll(nextItems);
  }
}

class NonReactiveList {
  final items = <int>[];

  void replace(List<int> nextItems) {
    items.clear();
    items.addAll(nextItems);
  }
}

class NotImmediate {
  final items = <int>[].obs;

  void replace(List<int> nextItems) {
    items.clear();
    if (nextItems.isNotEmpty) {
      items.addAll(nextItems);
    }
  }
}
