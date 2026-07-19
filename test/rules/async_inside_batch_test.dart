import 'package:all_observer_lint/src/rules/async_inside_batch.dart';
import 'package:test/test.dart';

import '../support/custom_lint_test_support.dart';
import '../support/resolve_fixture.dart';

void main() {
  group('async_inside_batch', () {
    test('flags a directly async batch callback', () async {
      final rule = AsyncInsideBatch(configs: await testConfigs());
      final result = await resolveFixture('async_inside_batch_invalid.dart');
      expect(await rule.testRun(result), hasLength(2));
    });

    test(
      'does not infer async from calls inside a synchronous callback',
      () async {
        final rule = AsyncInsideBatch(configs: await testConfigs());
        final result = await resolveFixture('async_inside_batch_valid.dart');
        expect(await rule.testRun(result), isEmpty);
      },
    );
  });
}
