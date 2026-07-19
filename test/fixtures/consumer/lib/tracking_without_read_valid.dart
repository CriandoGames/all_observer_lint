import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

class ValidScopes extends StatelessWidget {
  ValidScopes({super.key});

  static String helper() => 'possibly reactive';

  final count = 0.obs;
  final items = <int>[1].obs;
  late final doubled = Computed(() => count.value * 2);
  late final disposeEffect = effect(() => count.value.toString());
  late final ambiguousComputed = Computed(() => helper());

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${count.value} ${items.length}'));
  }
}
