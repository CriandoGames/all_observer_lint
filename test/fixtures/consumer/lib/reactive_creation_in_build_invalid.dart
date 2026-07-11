import 'package:all_observer/all_observer.dart';
import 'package:all_observer/all_observer.dart' as ao;
import 'package:flutter/material.dart';

class DirectObsWidget extends StatelessWidget {
  const DirectObsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final count = 0.obs;
    return Text('${count.value}');
  }
}

class ComputedInBuildWidget extends StatelessWidget {
  const ComputedInBuildWidget({
    super.key,
    required this.price,
    required this.quantity,
  });

  final Observable<int> price;
  final Observable<int> quantity;

  @override
  Widget build(BuildContext context) {
    final total = Computed(() => price.value * quantity.value);
    return Observer(() => Text('${total.value}'));
  }
}

class ObservableFutureInBuildWidget extends StatelessWidget {
  const ObservableFutureInBuildWidget({super.key});

  Future<int> loadUser() async => 1;

  @override
  Widget build(BuildContext context) {
    final request = ObservableFuture(loadUser);
    return const SizedBox();
  }
}

class AliasedObservableInBuildWidget extends StatelessWidget {
  const AliasedObservableInBuildWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final value = ao.Observable(0);
    return Text('${value.value}');
  }
}

class ObserverCallbackCreationWidget extends StatelessWidget {
  const ObserverCallbackCreationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Observer(() {
      final inner = 0.obs;
      return Text('${inner.value}');
    });
  }
}
