import 'dart:io';

import 'package:all_observer_lint/src/rules/unused_reactive_state.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

void main() {
  group('unused_reactive_state', () {
    test(
      'flags private reactive fields and top-level variables with no use',
      () async {
        final result = await resolveFixture(
          'unused_reactive_state_invalid.dart',
        );
        final rule = UnusedReactiveState(configs: await _configs());

        final errors = await rule.testRun(result);

        expect(errors, hasLength(4));
        expect(
          errors.map((error) => error.errorCode.name),
          everyElement(rule.code.name),
        );
      },
    );

    test(
      'does not flag private reactive state referenced in the file',
      () async {
        final result = await resolveFixture('unused_reactive_state_valid.dart');
        final rule = UnusedReactiveState(configs: await _configs());

        final errors = await rule.testRun(result);

        expect(errors, isEmpty);
      },
    );
  });
}

Future<CustomLintConfigs> _configs() async {
  final packageConfig = await parsePackageConfig(Directory.current);
  return CustomLintConfigs.parse(null, packageConfig);
}
