import 'package:all_observer_lint/src/rules/tracking_scope_without_reactive_read.dart';
import 'package:test/test.dart';

import '../support/custom_lint_test_support.dart';
import '../support/resolve_fixture.dart';

void main() {
  test(
    'reports Observer, Computed, and effect with proven empty tracking',
    () async {
      final result = await resolveFixture('tracking_without_read_invalid.dart');
      final configs = await testConfigs();

      expect(
        await ObserverWithoutReactiveRead(configs: configs).testRun(result),
        hasLength(1),
      );
      expect(
        await ComputedWithoutReactiveRead(configs: configs).testRun(result),
        hasLength(1),
      );
      expect(
        await EffectWithoutReactiveRead(configs: configs).testRun(result),
        hasLength(1),
      );
    },
  );

  test(
    'allows reads and stays silent for a helper that may hide a read',
    () async {
      final result = await resolveFixture('tracking_without_read_valid.dart');
      final configs = await testConfigs();

      expect(
        await ObserverWithoutReactiveRead(configs: configs).testRun(result),
        isEmpty,
      );
      expect(
        await ComputedWithoutReactiveRead(configs: configs).testRun(result),
        isEmpty,
      );
      expect(
        await EffectWithoutReactiveRead(configs: configs).testRun(result),
        isEmpty,
      );
    },
  );

  test(
    'stays silent for helpers called through this/an instance target and '
    'for reads hidden inside a nested closure',
    () async {
      final result = await resolveFixture(
        'tracking_helpers_with_targets_valid.dart',
      );
      final configs = await testConfigs();

      expect(
        await ComputedWithoutReactiveRead(configs: configs).testRun(result),
        isEmpty,
      );
    },
  );

  test(
    'recognizes map/where/contains/join/keys and for-in/spread iteration '
    'over a reactive collection as reads',
    () async {
      final result = await resolveFixture(
        'reactive_collection_reads_valid.dart',
      );
      final configs = await testConfigs();

      expect(
        await ObserverWithoutReactiveRead(configs: configs).testRun(result),
        isEmpty,
      );
      expect(
        await ComputedWithoutReactiveRead(configs: configs).testRun(result),
        isEmpty,
      );
    },
  );

  test(
    'Observer.withChild only inspects the builder callback, never the '
    'child argument',
    () async {
      final result = await resolveFixture('observer_with_child_tracking.dart');
      final configs = await testConfigs();

      // BuilderReadsValue: not flagged (builder itself reads count.value).
      // BuilderHasNoRead: flagged (builder has zero reads).
      // ReadOnlyInChildArgument: flagged (the read is in `child`, which
      // does not count toward the builder's own tracking scope).
      expect(
        await ObserverWithoutReactiveRead(configs: configs).testRun(result),
        hasLength(2),
      );
    },
  );

  test('stays silent for unresolved callbacks', () async {
    final result = await resolveFixture(
      'tracking_unresolved_valid.dart',
      allowErrors: true,
    );
    final configs = await testConfigs();
    expect(
      await ObserverWithoutReactiveRead(configs: configs).testRun(result),
      isEmpty,
    );
    expect(
      await ComputedWithoutReactiveRead(configs: configs).testRun(result),
      isEmpty,
    );
    expect(
      await EffectWithoutReactiveRead(configs: configs).testRun(result),
      isEmpty,
    );
  });
}
