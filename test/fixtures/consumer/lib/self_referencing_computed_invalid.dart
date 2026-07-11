import 'package:all_observer/all_observer.dart';

class DirectSelfReference {
  late final Computed<int> total = Computed(() => total.value + 1);
}

class AssignedSelfReference {
  late final Computed<int> total;

  void init() {
    total = Computed(() => total.value + 1);
  }
}

class ThisAssignedSelfReference {
  late final Computed<int> total;

  void init() {
    this.total = Computed(() => this.total.value + 1);
  }
}
