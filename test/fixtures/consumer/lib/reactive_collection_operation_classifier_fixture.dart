import 'package:all_observer/all_observer.dart';

/// Fixture for
/// `test/utils/reactive_collection_operation_classifier_test.dart`. Every
/// method groups calls of exactly one
/// `ReactiveCollectionOperationKind` so the test can assert on a whole
/// method body at once.
class CollectionOperationsFixture {
  final ObservableList<int> list = ObservableList<int>([1, 2, 3]);
  final ObservableMap<String, int> map = ObservableMap<String, int>({'a': 1});
  final ObservableSet<int> reactiveSet = ObservableSet<int>({1, 2, 3});

  void listReads() {
    list.length;
    list.elementAt(0);
    list.where((element) => element > 1);
    list.contains(1);
    list.toList();
  }

  void listMutations() {
    list.add(4);
    list.addAll([5, 6]);
    list.removeAt(0);
    list.removeLast();
    list.sort();
    list.shuffle();
    list.removeWhere((element) => element == 0);
    list.retainWhere((element) => element != 0);
    list.clear();
  }

  void listReplacements() {
    list.assign(1);
    list.assignAll([1, 2]);
  }

  void listUnknown() {
    // `toString` is a real, resolved member of `ObservableList` (from
    // `Object`), but it is neither a known read nor a known mutation of the
    // reactive collection surface — must classify as `unknown`, never a
    // guessed mutation.
    list.toString();
  }

  void listIndexRead() {
    // ignore: unused_local_variable
    final value = list[0];
  }

  void listIndexWrite() {
    list[0] = 9;
  }

  void listLengthWrite() {
    list.length = 1;
  }

  void mapReads() {
    map.containsKey('a');
    map.length;
    map.keys;
  }

  void mapMutations() {
    map.addAll({'b': 2});
    map.remove('a');
    map.putIfAbsent('c', () => 3);
    map.update('c', (value) => value + 1);
    map.updateAll((key, value) => value);
    map.removeWhere((key, value) => value == 0);
    map.clear();
  }

  void mapIndexRead() {
    // ignore: unused_local_variable
    final value = map['a'];
  }

  void mapIndexWrite() {
    map['a'] = 10;
  }

  void setReads() {
    reactiveSet.contains(1);
    reactiveSet.length;
    reactiveSet.toSet();
  }

  void setMutations() {
    reactiveSet.add(4);
    reactiveSet.addAll([5, 6]);
    reactiveSet.removeWhere((element) => element == 0);
    reactiveSet.retainAll([1, 2]);
    reactiveSet.clear();
  }
}
