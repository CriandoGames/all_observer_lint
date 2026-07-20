// ignore_for_file: experimental_member_use

import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:all_observer_lint/src/utils/computed_callback_finder.dart';
import 'package:all_observer_lint/src/utils/reactive_write_detector.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

/// Covers the four rules that replaced the broad
/// `avoid_side_effects_in_computed` idea (see
/// `documentation/backlog.md`, "Why not one avoid_side_effects_in_computed
/// rule"): avoid_reactive_write_in_computed, avoid_set_state_in_computed,
/// avoid_worker_creation_in_computed, avoid_io_in_computed.
void main() {
  final checker = AllObserverTypeChecker();
  final writeDetector = ReactiveWriteDetector(checker);
  final finder = ComputedCallbackFinder(checker);

  group('avoid_reactive_write_in_computed', () {
    int countWrites(CompilationUnit unit) {
      var count = 0;
      unit.accept(
        _ComputedVisitor(checker, (callback) {
          count += writeDetector
              .findIn(callback, includeNestedFunctions: true)
              .length;
        }),
      );
      return count;
    }

    test('flags assignment and increment writes inside Computed', () async {
      final result = await resolveFixture('computed_purity_invalid.dart');
      // ImpureState: name.value = 'Unknown' (1)
      // ImpureCounter: counter.value++ (1)
      expect(countWrites(result.unit), 2);
    });

    test('does not flag pure derivations, nested pure closures, or '
        'unrelated .value fields', () async {
      final result = await resolveFixture('computed_purity_valid.dart');
      expect(countWrites(result.unit), 0);
    });
  });

  group('avoid_set_state_in_computed', () {
    int countSetState(CompilationUnit unit) {
      var count = 0;
      unit.accept(
        _MethodInvocationInComputedVisitor(
          finder,
          (node) => checker.isSetStateInvocation(node),
          () => count++,
        ),
      );
      return count;
    }

    test('flags setState inside Computed', () async {
      final result = await resolveFixture('computed_purity_invalid.dart');
      expect(countSetState(result.unit), 1);
    });

    test('does not flag setState outside Computed', () async {
      final result = await resolveFixture('computed_purity_valid.dart');
      expect(countSetState(result.unit), 0);
    });
  });

  group('avoid_worker_creation_in_computed', () {
    int countWorkers(CompilationUnit unit) {
      var count = 0;
      unit.accept(
        _MethodInvocationInComputedVisitor(
          finder,
          (node) => checker.isEffectOrWorkerInvocation(node),
          () => count++,
        ),
      );
      return count;
    }

    test('flags ever(...) registered inside Computed', () async {
      final result = await resolveFixture('computed_purity_invalid.dart');
      expect(countWorkers(result.unit), 1);
    });

    test('does not flag workers outside Computed', () async {
      final result = await resolveFixture('computed_purity_valid.dart');
      expect(countWorkers(result.unit), 0);
    });
  });

  group('avoid_io_in_computed', () {
    int countIo(CompilationUnit unit) {
      var count = 0;
      unit.accept(_IoVisitor(finder, () => count++));
      return count;
    }

    test('flags dart:io calls and await expressions inside Computed', () async {
      final result = await resolveFixture('computed_purity_invalid.dart');
      // IoInComputed: File(...).existsSync() (1) + await (1)
      expect(countIo(result.unit), 2);
    });

    test('does not flag pure derivations', () async {
      final result = await resolveFixture('computed_purity_valid.dart');
      expect(countIo(result.unit), 0);
    });
  });
}

class _ComputedVisitor extends RecursiveAstVisitor<void> {
  _ComputedVisitor(this._checker, this._onCallback);

  final AllObserverTypeChecker _checker;
  final void Function(FunctionExpression callback) _onCallback;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_checker.isComputedCreation(node)) {
      for (final argument in node.argumentList.arguments) {
        final value = argument is NamedExpression
            ? argument.expression
            : argument;
        if (value is FunctionExpression) {
          _onCallback(value);
          break;
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

class _MethodInvocationInComputedVisitor extends RecursiveAstVisitor<void> {
  _MethodInvocationInComputedVisitor(
    this._finder,
    this._matches,
    this._onOffense,
  );

  final ComputedCallbackFinder _finder;
  final bool Function(MethodInvocation) _matches;
  final void Function() _onOffense;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_matches(node) && _finder.isInsideComputedCallback(node)) {
      _onOffense();
    }
    super.visitMethodInvocation(node);
  }
}

class _IoVisitor extends RecursiveAstVisitor<void> {
  _IoVisitor(this._finder, this._onOffense);

  final ComputedCallbackFinder _finder;
  final void Function() _onOffense;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    if (_finder.isInsideComputedCallback(node)) _onOffense();
    super.visitAwaitExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final library = node.methodName.element?.library?.identifier;
    if (library != null &&
        library.startsWith('dart:io') &&
        _finder.isInsideComputedCallback(node)) {
      _onOffense();
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_isImmediateTargetOfDartIoMethodInvocation(node)) {
      super.visitInstanceCreationExpression(node);
      return;
    }
    final library = node.constructorName.type.element?.library?.identifier;
    if (library != null &&
        library.startsWith('dart:io') &&
        _finder.isInsideComputedCallback(node)) {
      _onOffense();
    }
    super.visitInstanceCreationExpression(node);
  }

  bool _isImmediateTargetOfDartIoMethodInvocation(
    InstanceCreationExpression node,
  ) {
    final parent = node.parent;
    if (parent is! MethodInvocation || !identical(parent.target, node)) {
      return false;
    }
    final library = parent.methodName.element?.library?.identifier;
    return library != null && library.startsWith('dart:io');
  }
}
