import 'package:all_observer_lint/src/rules/invalid_history_limit.dart';
import 'package:test/test.dart';

import '../support/custom_lint_test_support.dart';
import '../support/resolve_fixture.dart';

void main() {
  group('invalid_history_limit', () {
    test('flags only known constants at or below zero', () async {
      final rule = InvalidHistoryLimit(configs: await testConfigs());
      final result = await resolveFixture('invalid_history_limit_invalid.dart');
      expect(await rule.testRun(result), hasLength(3));
    });

    test('allows positive, omitted, and non-constant limits', () async {
      final rule = InvalidHistoryLimit(configs: await testConfigs());
      final result = await resolveFixture('invalid_history_limit_valid.dart');
      expect(await rule.testRun(result), isEmpty);
    });
  });
}
