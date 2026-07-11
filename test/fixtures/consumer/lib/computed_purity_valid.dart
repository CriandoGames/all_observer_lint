import 'package:all_observer/all_observer.dart';

class PureState {
  final name = ''.obs;

  late final normalized = Computed(
    () => name.value.isEmpty ? 'Unknown' : name.value.trim(),
  );
}

class PureListDerivation {
  final items = <int>[1, 2, 3].obs;

  // Pure, side-effect-free nested closures (map/where/fold) are allowed.
  late final total = Computed(
    () => items.value.where((i) => i > 0).fold<int>(0, (a, b) => a + b),
  );
}

class ReadsOtherComputed {
  final base = 1.obs;
  late final doubled = Computed(() => base.value * 2);
  late final quadrupled = Computed(() => doubled.value * 2);
}

// A local variable named `value` and a method named `value` on an
// unrelated type must never be confused with `.value` on a reactive value.
class NotReactive {
  int value = 0;
}

class UsesUnrelatedValueField {
  late final unrelated = Computed(() {
    final holder = NotReactive();
    holder.value = 10;
    return holder.value;
  });
}
