import 'dart:io';

import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';

class ImpureState {
  final name = ''.obs;

  late final normalized = Computed(() {
    if (name.value.isEmpty) {
      name.value = 'Unknown';
    }
    return name.value.trim();
  });
}

class ImpureCounter {
  final counter = 0.obs;

  late final incrementing = Computed(() {
    counter.value++;
    return counter.value;
  });
}

class MyState extends State<StatefulWidget> {
  final flag = false.obs;

  late final withSetState = Computed(() {
    // ignore: invalid_use_of_protected_member
    setState(() {});
    return flag.value;
  });

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class WorkerInComputed {
  final counter = 0.obs;

  late final withWorker = Computed(() {
    ever(counter, (value) {});
    return counter.value;
  });
}

class IoInComputed {
  final path = ''.obs;

  late final withIo = Computed(() {
    return File(path.value).existsSync();
  });

  late final withAwait = Computed(() async {
    // ignore: unnecessary_await_in_return
    await Future<void>.delayed(Duration.zero);
    return path.value;
  });
}
