// Run with: dart run benchmark/assist_benchmark.dart
//
// Prerequisite: `cd test/fixtures/consumer && flutter pub get` (same as the
// test suite, see `test/support/resolve_fixture.dart`).
//
// Measures `WrapWithObserverAssist.testRun` over a large generated widget
// tree, before vs. after the Part 1 rewrite is best compared by running this
// same script against two checkouts (the pre-change commit
// `69c8ffbcaaab76d025da623082ac9122a2dad64e` and the current branch) on the
// same machine — see `documentation/architecture.md`.
import 'dart:io';

import 'package:all_observer_lint/src/assists/wrap_with_observer_assist.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:path/path.dart' as p;

import '../test/support/resolve_fixture.dart';
import 'fixtures/generators.dart';
import 'support/bench_stats.dart';

Future<void> main() async {
  for (final widgetCount in [50, 200, 800]) {
    await _runFor(widgetCount);
  }
}

Future<void> _runFor(int widgetCount) async {
  final generated = generateAssistFixture(widgetCount);
  final fileName = '_bench_assist_generated_$widgetCount.dart';
  final file = File(p.join(consumerFixtureRoot, 'lib', fileName));
  file.writeAsStringSync(generated.source);

  try {
    final result = await resolveFixture(fileName, allowErrors: true);
    final source = file.readAsStringSync();
    final assist = WrapWithObserverAssist();

    final offsets = generated.markers
        .map((marker) => source.indexOf(marker))
        .where((offset) => offset >= 0)
        .toList();

    var cursor = 0;
    final benchResult = await measureAsync(
      label: 'WrapWithObserverAssist.testRun x${offsets.length} '
          '(widgetCount=$widgetCount)',
      body: () async {
        final offset = offsets[cursor % offsets.length];
        cursor++;
        await assist.testRun(result, SourceRange(offset, 0));
      },
      warmup: 3,
      repeat: 15,
    );
    print(benchResult.format());
  } finally {
    if (file.existsSync()) file.deleteSync();
  }
}
