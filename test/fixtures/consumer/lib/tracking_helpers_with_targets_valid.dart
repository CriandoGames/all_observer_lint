import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

/// Regression coverage for the *_without_reactive_read rules: a `Computed`
/// whose callback only calls a helper through `this`, an instance target,
/// or a nested closure must stay silent rather than assert there is no
/// reactive read at all — the helper or nested closure may read a reactive
/// value we did not analyze.
class Controller {
  int calculate() => 42;
}

class HelperTrackingScopes extends StatelessWidget {
  HelperTrackingScopes({super.key, required this.controller});
  final Controller controller;

  final count = 0.obs;

  late final helperWithThis = Computed(() => this._helper());
  late final helperWithTarget = Computed(() => controller.calculate());
  late final callbackRead = Computed(
    () => <int>[1, 2, 3].map((_) => count.value).toList().length,
  );

  int _helper() => 42;

  @override
  Widget build(BuildContext context) => Observer(() => const SizedBox());
}
