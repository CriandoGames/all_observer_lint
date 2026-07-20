// Run with: dart run benchmark/rules_benchmark.dart
//
// Prerequisite: `cd test/fixtures/consumer && flutter pub get`.
//
// Measures `unused_reactive_state` and `dispose_reactive_resources` over
// generated fixtures of increasing size. The optimized rules build one
// index per compilation unit/class instead of one full traversal per
// candidate, so timings here should grow roughly linearly with N (fields /
// resources), not quadratically. Compare against the pre-change commit
// `69c8ffbcaaab76d025da623082ac9122a2dad64e` on the same machine to see the
// asymptotic difference directly.
import 'dart:io';

import 'package:all_observer_lint/src/rules/dispose_reactive_resources.dart';
import 'package:all_observer_lint/src/rules/unused_reactive_state.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:path/path.dart' as p;

import '../test/support/resolve_fixture.dart';
import 'fixtures/generators.dart';
import 'support/bench_stats.dart';

Future<void> main() async {
  final configs = await _configs();

  print('-- unused_reactive_state --');
  for (final fieldCount in [10, 100, 500]) {
    await _runUnusedReactiveState(fieldCount, configs);
  }

  print('-- dispose_reactive_resources --');
  for (final resourceCount in [5, 20, 100]) {
    await _runDisposeReactiveResources(resourceCount, configs);
  }
}

Future<void> _runUnusedReactiveState(
  int fieldCount,
  CustomLintConfigs configs,
) async {
  final source = generateUnusedReactiveStateFixture(fieldCount);
  final fileName = '_bench_unused_reactive_state_$fieldCount.dart';
  final file = File(p.join(consumerFixtureRoot, 'lib', fileName));
  file.writeAsStringSync(source);

  try {
    final result = await resolveFixture(fileName);
    final rule = UnusedReactiveState(configs: configs);
    final benchResult = await measureAsync(
      label: 'unused_reactive_state (fieldCount=$fieldCount)',
      body: () async {
        // ignore: invalid_use_of_visible_for_testing_member
        await rule.testRun(result);
      },
    );
    print(benchResult.format());
  } finally {
    if (file.existsSync()) file.deleteSync();
  }
}

Future<void> _runDisposeReactiveResources(
  int resourceCount,
  CustomLintConfigs configs,
) async {
  final source = generateDisposeReactiveResourcesFixture(resourceCount);
  final fileName = '_bench_dispose_reactive_resources_$resourceCount.dart';
  final file = File(p.join(consumerFixtureRoot, 'lib', fileName));
  file.writeAsStringSync(source);

  try {
    final result = await resolveFixture(fileName);
    final rule = DisposeReactiveResources(configs: configs);
    final benchResult = await measureAsync(
      label: 'dispose_reactive_resources (resourceCount=$resourceCount)',
      body: () async {
        // ignore: invalid_use_of_visible_for_testing_member
        await rule.testRun(result);
      },
    );
    print(benchResult.format());
  } finally {
    if (file.existsSync()) file.deleteSync();
  }
}

Future<CustomLintConfigs> _configs() async {
  final packageConfig = await parsePackageConfig(Directory.current);
  return CustomLintConfigs.parse(null, packageConfig);
}
