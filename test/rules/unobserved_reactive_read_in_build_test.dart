import 'dart:io';

import 'package:all_observer_lint/src/rules/unobserved_reactive_read_in_build.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

void main() {
  group('unobserved_reactive_read_in_build', () {
    test('flags reactive value reads rendered directly in build', () async {
      final result = await resolveFixture(
        'unobserved_reactive_read_in_build_invalid.dart',
      );
      final rule = UnobservedReactiveReadInBuild(configs: await _configs());

      final errors = await rule.testRun(result);

      expect(errors, hasLength(3));
      expect(
        errors.map((error) => error.errorCode.name),
        everyElement(rule.code.name),
      );
    });

    test(
      'does not flag reads inside Observer, watch, or event handlers',
      () async {
        final result = await resolveFixture(
          'unobserved_reactive_read_in_build_valid.dart',
        );
        final rule = UnobservedReactiveReadInBuild(configs: await _configs());

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
