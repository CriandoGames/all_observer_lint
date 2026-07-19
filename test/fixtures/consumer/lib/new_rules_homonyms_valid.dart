import 'package:another_package/observer.dart' as other;

class Observable<T> {
  Observable(this.value);
  T value;
  History withHistory({int limit = 100}) => History(limit);
  static void batch(void Function() callback) => callback();
}

class History {
  History(this.limit);
  final int limit;
}

void localApis() {
  final value = Observable(0);
  value.withHistory(limit: 0);
  Observable.batch(() async {});
  other.Computed(() => 42);
}
