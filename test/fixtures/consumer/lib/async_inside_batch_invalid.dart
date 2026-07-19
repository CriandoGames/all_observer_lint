import 'package:all_observer/all_observer.dart';

Future<void> save() async {}
void asyncCallback() async => save();

void update() {
  Observable.batch(() async {
    await save();
  });
  Observable.batch(asyncCallback);
}
