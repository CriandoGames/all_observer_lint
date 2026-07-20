// Run with: dart run benchmark/semantic_index_benchmark.dart
//
// Prerequisite: `cd test/fixtures/consumer && flutter pub get`.
//
// Measures `UnitSemanticIndex.build` plus every lazy capability
// (`references`, `reactiveReads`, `reactiveMutations`,
// `listenerRegistrations`, `listenerRemovals`) over an increasing field
// count. `build` itself only collects declarations (one traversal); each
// lazy capability adds exactly one more traversal the first time it is
// touched, regardless of how many candidate fields exist — so total work
// should grow linearly with field count and stay flat across the small,
// fixed number of capability traversals, not multiply per-field.
import 'dart:io';

import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:all_observer_lint/src/utils/semantic_reference_index.dart';
import 'package:path/path.dart' as p;

import '../test/support/resolve_fixture.dart';
import 'fixtures/generators.dart';
import 'support/bench_stats.dart';

Future<void> main() async {
  for (final fieldCount in [10, 100, 500]) {
    await _runFor(fieldCount);
  }
}

Future<void> _runFor(int fieldCount) async {
  final source = generateSemanticIndexFixture(fieldCount);
  final fileName = '_bench_semantic_index_$fieldCount.dart';
  final file = File(p.join(consumerFixtureRoot, 'lib', fileName));
  file.writeAsStringSync(source);

  try {
    final result = await resolveFixture(fileName, allowErrors: true);
    final checker = AllObserverTypeChecker();

    final buildResult = measure(
      label: 'UnitSemanticIndex.build (fieldCount=$fieldCount)',
      body: () {
        UnitSemanticIndex.build(result.unit, checker);
      },
    );
    print(buildResult.format());

    final capabilitiesResult = measure(
      label: 'UnitSemanticIndex all capabilities (fieldCount=$fieldCount)',
      body: () {
        final index = UnitSemanticIndex.build(result.unit, checker);
        // Touch every lazy capability once, exactly as a migration
        // analyzer that needs all of them would.
        index.references;
        index.reactiveReads;
        index.reactiveMutations;
        index.listenerRegistrations;
        index.listenerRemovals;
      },
    );
    print(capabilitiesResult.format());
  } finally {
    if (file.existsSync()) file.deleteSync();
  }
}
