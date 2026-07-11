import 'package:all_observer/all_observer.dart';
import 'package:another_package/observer.dart' as other hide FakeObsExtension;

class ReadsObservable {
  final base = 1.obs;

  late final total = Computed(() => base.value + 1);
}

class ReadsAnotherComputed {
  final base = 1.obs;

  late final doubled = Computed(() => base.value * 2);
  late final quadrupled = Computed(() => doubled.value * 2);
}

class NotReactive {
  int value = 0;
}

class ShadowedLocalName {
  late final Computed<int> total = Computed(() {
    final total = NotReactive();
    return total.value + 1;
  });
}

class NestedLocalFunction {
  late final Computed<int> total = Computed(() {
    int readLater() => total.value + 1;
    return 1;
  });
}

class HomonymousComputedFromAnotherPackage {
  late final other.Computed<int> fake = other.Computed(() => fake.value + 1);
}
