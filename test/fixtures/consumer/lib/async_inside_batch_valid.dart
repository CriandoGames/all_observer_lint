import 'package:all_observer/all_observer.dart';

Future<void> save() async {}

Future<void> update() async {
  await save();
  Observable.batch(() {
    final value = 1;
    value.toString();
  });
}

void conservative() {
  Observable.batch(() {
    save();
  });
}
