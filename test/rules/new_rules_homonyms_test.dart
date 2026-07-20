import 'package:all_observer_lint/src/rules/async_inside_batch.dart';
import 'package:all_observer_lint/src/rules/copied_reactive_collection_outside_tracking.dart';
import 'package:all_observer_lint/src/rules/invalid_history_limit.dart';
import 'package:all_observer_lint/src/rules/tracking_scope_without_reactive_read.dart';
import 'package:test/test.dart';

import '../support/custom_lint_test_support.dart';
import '../support/resolve_fixture.dart';

void main() {
  test('new rules ignore homonymous APIs from other libraries', () async {
    final result = await resolveFixture('new_rules_homonyms_valid.dart');
    final configs = await testConfigs();

    expect(
      await InvalidHistoryLimit(configs: configs).testRun(result),
      isEmpty,
    );
    expect(await AsyncInsideBatch(configs: configs).testRun(result), isEmpty);
    expect(
      await ComputedWithoutReactiveRead(configs: configs).testRun(result),
      isEmpty,
    );
    expect(
      await CopiedReactiveCollectionOutsideTracking(
        configs: configs,
      ).testRun(result),
      isEmpty,
    );
  });
}
