import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

Widget unresolvedObserver() {
  return Observer(() => missingHelper());
}

final unresolvedComputed = Computed(() => missingValue());
final unresolvedEffect = effect(() => missingEffect());
