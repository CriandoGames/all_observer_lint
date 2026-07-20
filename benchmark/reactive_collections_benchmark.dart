// Run with: dart run benchmark/reactive_collections_benchmark.dart
//
// Prerequisite: `cd test/fixtures/consumer && flutter pub get`.
//
// Measures `ReactiveCollectionOperationClassifier.classifyMethodInvocation`
// over an increasing number of collection operations on a single
// `ObservableList`. The classifier does a fixed amount of work per call
// (one type-hierarchy lookup already memoized by `AllObserverTypeChecker`,
// plus a couple of `Set.contains` checks), so timings here should grow
// linearly with the number of *classified calls* per run, not with the
// number of operations in the fixture — this benchmark instead varies how
// many calls a single `run()` benchmark iteration classifies, to show the
// per-call cost stays flat as that count grows.
import 'dart:io';

import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:all_observer_lint/src/utils/reactive_collection_operation_classifier.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../test/support/resolve_fixture.dart';
import 'fixtures/generators.dart';
import 'support/bench_stats.dart';

Future<void> main() async {
  for (final operationCount in [10, 100, 500]) {
    await _runFor(operationCount);
  }
}

Future<void> _runFor(int operationCount) async {
  final source = generateReactiveCollectionOperationsFixture(operationCount);
  final fileName = '_bench_reactive_collections_$operationCount.dart';
  final file = File(p.join(consumerFixtureRoot, 'lib', fileName));
  file.writeAsStringSync(source);

  try {
    final result = await resolveFixture(fileName, allowErrors: true);
    final collector = _MethodInvocationCollector();
    result.unit.accept(collector);
    final classifier = ReactiveCollectionOperationClassifier(
      AllObserverTypeChecker(),
    );

    final benchResult = measure(
      label: 'classifyMethodInvocation x${collector.invocations.length} '
          '(operationCount=$operationCount)',
      body: () {
        for (final invocation in collector.invocations) {
          classifier.classifyMethodInvocation(invocation);
        }
      },
    );
    print(benchResult.format());
  } finally {
    if (file.existsSync()) file.deleteSync();
  }
}

class _MethodInvocationCollector extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target != null) invocations.add(node);
    super.visitMethodInvocation(node);
  }
}
