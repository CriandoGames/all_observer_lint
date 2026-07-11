import 'package:all_observer/all_observer.dart';
import 'package:another_package/observer.dart' as other hide FakeObsExtension;
import 'package:flutter/material.dart';

class FieldObservableWidget extends StatefulWidget {
  const FieldObservableWidget({super.key});

  @override
  State<FieldObservableWidget> createState() => _FieldObservableWidgetState();
}

class _FieldObservableWidgetState extends State<FieldObservableWidget> {
  final count = 0.obs;
  late final total = Computed(() => count.value * 2);

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${count.value} ${total.value}'));
  }
}

class EventHandlerClosureWidget extends StatelessWidget {
  const EventHandlerClosureWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // Only created when the button is pressed, not on every rebuild.
        final temp = 0.obs;
        temp.value = 1;
      },
      child: const Text('tap'),
    );
  }
}

class HomonymSymbolWidget extends StatelessWidget {
  const HomonymSymbolWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // `Observable` here comes from `another_package`, not `all_observer`.
    final fake = other.Observable<int>(0);
    return Text('${fake.value}');
  }
}

void topLevelHelper() {
  final unrelated = 0.obs;
  unrelated.value = 1;
}
