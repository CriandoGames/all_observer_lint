import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Guards `test/fixtures/fake_all_observer` — the stand-in every other
/// fixture in this repo resolves against — from silently drifting away
/// from the real, published `all_observer` package's public shape again.
///
/// This does not replace `test/fixtures/real_runtime_smoke` (which proves
/// this package's rules and fixes actually behave correctly against the
/// real package, but needs network access to fetch it). This test needs
/// no network: it re-checks, every time the suite runs, the exact
/// signatures that were read directly from the real `all_observer` source
/// (commit `1989e0864e551a7dc89712043594ab0ab716b110`, version `1.5.6`) the
/// last time this fake was audited — see `documentation/backlog.md` and the
/// `CHANGELOG.md` 0.5.1 entry for that audit. If one of these checks ever
/// fails, the fake was edited without re-verifying it against the real
/// package; do that before changing the expectation here.
void main() {
  late String source;

  setUpAll(() {
    final path = p.join(
      Directory.current.path,
      'test',
      'fixtures',
      'fake_all_observer',
      'lib',
      'all_observer.dart',
    );
    source = File(path).readAsStringSync();
  });

  group('fake_all_observer stays shaped like the real all_observer', () {
    test('debounce/interval require the named time: parameter', () {
      expect(
        source,
        contains('Worker debounce<T>('),
        reason: 'debounce signature moved or was removed',
      );
      expect(
        source,
        contains('Worker interval<T>('),
        reason: 'interval signature moved or was removed',
      );
      // The real package declares `time` as `required Duration time`, not
      // an optional parameter with a default — see workers.dart at the
      // pinned commit. A default here would silently accept fixtures that
      // call debounce/interval without `time:`, which the real package
      // rejects at compile time.
      final debounceToInterval = source.substring(
        source.indexOf('Worker debounce<T>('),
        source.indexOf('Worker interval<T>(') +
            'Worker interval<T>('.length +
            200,
      );
      expect(
        debounceToInterval,
        contains('required Duration time'),
        reason: 'debounce/interval must require `time:`, not default it',
      );
    });

    test('ObservableList/Map/Set extend the same dart:collection base '
        'classes as the real package', () {
      expect(
        source,
        contains('class ObservableList<E> extends ListBase<E>'),
        reason:
            'the real ObservableList<E> extends ListBase<E> directly (it '
            'is a List, not a CoreObservable<List<E>> wrapper) — this '
            'affects static-type-based member resolution, iteration, and '
            'collection literals throughout the rules',
      );
      expect(
        source,
        contains('class ObservableMap<K, V> extends MapBase<K, V>'),
      );
      expect(source, contains('class ObservableSet<E> extends SetBase<E>'));
    });

    test('Disposer is the real void-callback alias, and effect() returns '
        'one', () {
      expect(source, contains('typedef Disposer = void Function();'));
      expect(
        source,
        contains('Disposer effect('),
        reason:
            'effect() must return Disposer so late final x = effect(...) '
            'infers the Disposer alias, not a structural function type',
      );
    });

    test('Observer supports both the plain and .withChild constructors', () {
      expect(source, contains('class Observer extends StatelessWidget'));
      expect(source, contains('const Observer.withChild('));
    });

    test('reactive collections expose assign/assignAll like the real '
        'ObservableList', () {
      expect(source, contains('void assign('));
      expect(source, contains('void assignAll('));
    });
  });
}
