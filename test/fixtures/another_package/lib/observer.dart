/// Intentionally shadows names from `all_observer` to verify
/// `AllObserverTypeChecker` matches by resolved library URI, never by
/// textual name.
class Observable<T> {
  Observable(this.value);
  T value;
}

class Observer {
  const Observer();
  void watch(Object context) {}
}

class Computed<T> {
  Computed(this.compute);
  final T Function() compute;
  T get value => compute();
}

extension FakeObsExtension<T> on T {
  Observable<T> get obs => Observable<T>(this);
}
