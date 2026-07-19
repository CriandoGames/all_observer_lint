import 'dart:io';

import 'package:all_observer_lint/src/rules/dispose_reactive_resources.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/custom_lint_test_support.dart';
import '../support/resolve_fixture.dart';

void main() {
  group('dispose_reactive_resources', () {
    test(
      'flags Worker, Disposer, and ObservableStream by static type',
      () async {
        final result = await resolveFixture(
          'dispose_reactive_resources_invalid.dart',
        );
        final rule = DisposeReactiveResources(configs: await testConfigs());

        final errors = await rule.testRun(result);

        expect(errors, hasLength(9));
      },
    );

    test('recognizes worker.dispose() and disposeEffect()', () async {
      final result = await resolveFixture(
        'dispose_reactive_resources_valid.dart',
      );
      final rule = DisposeReactiveResources(configs: await testConfigs());

      expect(await rule.testRun(result), isEmpty);
    });

    test(
      'flags effect() with an inferred Disposer type (no explicit '
      'annotation)',
      () async {
        final result = await resolveFixture(
          'dispose_effect_inferred_invalid.dart',
        );
        final rule = DisposeReactiveResources(configs: await testConfigs());

        final errors = await rule.testRun(result);
        expect(errors, hasLength(1));
      },
    );

    test(
      'accepts inferred Disposer, explicit function-type, and '
      'non-invocable effect() fields once proven safe',
      () async {
        final result = await resolveFixture(
          'dispose_effect_inferred_valid.dart',
        );
        final rule = DisposeReactiveResources(configs: await testConfigs());

        // UnsafeTypeState's `final Object disposeEffect = effect(() {});`
        // is never disposed, but must not be flagged: the declared type is
        // not invocable, so the rule cannot prove a safe disposal contract.
        expect(await rule.testRun(result), isEmpty);
      },
    );

    test(
      'quick fix invokes an inferred Disposer field before super.dispose '
      'and reanalyzes',
      () async {
        final result = await resolveFixture(
          'dispose_effect_fix_input_inferred.dart',
        );
        final source = File(result.path).readAsStringSync();
        final rule = DisposeReactiveResources(configs: await testConfigs());
        final errors = await rule.testRun(result);
        expect(errors, hasLength(1));

        final fix = rule.getFixes().single as DartFix;
        final changes = await fix.testRun(result, errors.single, errors);
        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);

        final tempName = '_dispose_effect_fix_result_inferred.dart';
        final tempFile = File(p.join(consumerFixtureRoot, 'lib', tempName));
        addTearDown(() {
          if (tempFile.existsSync()) tempFile.deleteSync();
        });
        tempFile.writeAsStringSync(transformed);
        final format = await Process.run('dart', ['format', tempFile.path]);
        expect(
          format.exitCode,
          0,
          reason: '${format.stdout}\n${format.stderr}',
        );

        final formatted = tempFile.readAsStringSync();
        final golden = File(
          p.join(
            Directory.current.path,
            'test',
            'goldens',
            'dispose_effect_fix_inferred.golden',
          ),
        ).readAsStringSync();
        expect(formatted, golden);

        final resolved = await resolveFixture(tempName);
        expect(await rule.testRun(resolved), isEmpty);
      },
    );

    test(
      'quick fix invokes Disposer before super.dispose and reanalyzes',
      () async {
        final result = await resolveFixture('dispose_effect_fix_input.dart');
        final source = File(result.path).readAsStringSync();
        final rule = DisposeReactiveResources(configs: await testConfigs());
        final errors = await rule.testRun(result);
        expect(errors, hasLength(1));

        final fix = rule.getFixes().single as DartFix;
        final changes = await fix.testRun(result, errors.single, errors);
        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);

        final tempName = '_dispose_effect_fix_result.dart';
        final tempFile = File(p.join(consumerFixtureRoot, 'lib', tempName));
        addTearDown(() {
          if (tempFile.existsSync()) tempFile.deleteSync();
        });
        tempFile.writeAsStringSync(transformed);
        final format = await Process.run('dart', ['format', tempFile.path]);
        expect(
          format.exitCode,
          0,
          reason: '${format.stdout}\n${format.stderr}',
        );

        final formatted = tempFile.readAsStringSync();
        final golden = File(
          p.join(
            Directory.current.path,
            'test',
            'goldens',
            'dispose_effect_fix.golden',
          ),
        ).readAsStringSync();
        expect(formatted, golden);

        final resolved = await resolveFixture(tempName);
        expect(await rule.testRun(resolved), isEmpty);
      },
    );
  });
}
