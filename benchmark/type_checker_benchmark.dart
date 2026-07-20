// Run with: dart run benchmark/type_checker_benchmark.dart
//
// Prerequisite: `cd test/fixtures/consumer && flutter pub get`.
//
// Measures `AllObserverTypeChecker`'s `is*Type` family under repeated calls
// against the same small set of root types (the common case: a rule
// re-checking the same class's fields, or the assist re-checking the same
// Widget classes across a file). The memoized hierarchy walk (Part 5)
// should make calls after the first one for a given type dramatically
// cheaper than the first, and repeated checker construction (one per
// execution, never shared/static) should stay cheap since each execution's
// cache starts cold and small.
import 'dart:io';

import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';

import '../test/support/resolve_fixture.dart';
import 'support/bench_stats.dart';

Future<void> main() async {
  // Reuses an existing fixture with a representative mix of Observable /
  // ObservableList / Computed / Widget declarations, rather than adding a
  // new one purely for this benchmark.
  final result = await resolveFixture('reactive_collection_reads_valid.dart');

  final collector = _TypeCollector();
  result.unit.accept(collector);
  final types = collector.types;
  print('Collected ${types.length} distinct expression types from fixture.');

  final coldResult = measure(
    label: 'first pass over all types (cold per-checker cache)',
    warmup: 0,
    repeat: 30,
    body: () {
      // A fresh checker every iteration: this is the "cold" case, exactly
      // what one rule execution looks like the first time it sees each
      // type.
      final checker = AllObserverTypeChecker();
      for (final type in types) {
        checker.isObservableType(type);
        checker.isComputedType(type);
        checker.isObservableListType(type);
        checker.isObservableMapType(type);
        checker.isObservableSetType(type);
        checker.isFlutterWidgetType(type);
      }
    },
  );
  print(coldResult.format());

  final warmChecker = AllObserverTypeChecker();
  // Prime the cache once.
  for (final type in types) {
    warmChecker.isFlutterWidgetType(type);
  }
  final warmResult = measure(
    label: 'repeated pass, same checker (warm cache)',
    warmup: 3,
    repeat: 30,
    body: () {
      for (final type in types) {
        warmChecker.isObservableType(type);
        warmChecker.isComputedType(type);
        warmChecker.isObservableListType(type);
        warmChecker.isObservableMapType(type);
        warmChecker.isObservableSetType(type);
        warmChecker.isFlutterWidgetType(type);
      }
    },
  );
  print(warmResult.format());

  final repeatedTypeResult = measure(
    label: 'thousands of repeated checks on one root type (warm)',
    body: () {
      if (types.isEmpty) return;
      final type = types.first;
      for (var i = 0; i < 5000; i++) {
        warmChecker.isFlutterWidgetType(type);
      }
    },
  );
  print(repeatedTypeResult.format());
}

class _TypeCollector extends RecursiveAstVisitor<void> {
  final List<DartType> types = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final type = node.staticType;
    if (type != null) types.add(type);
    super.visitSimpleIdentifier(node);
  }
}
