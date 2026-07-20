import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:all_observer_lint/src/utils/build_context_detector.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

void main() {
  final checker = AllObserverTypeChecker();
  final finder = RebuildScopeFinder(checker);

  int countOffenses(CompilationUnit unit) {
    var count = 0;
    unit.accept(_Visitor(checker, finder, () => count++));
    return count;
  }

  group('avoid_reactive_creation_in_build', () {
    test('flags .obs, Computed, ObservableFuture created in build/Observer, '
        'including aliased imports', () async {
      final result = await resolveFixture(
        'reactive_creation_in_build_invalid.dart',
      );
      expect(countOffenses(result.unit), 5);
    });

    test('does not flag fields, event-handler closures, or homonymous symbols '
        'from another package', () async {
      final result = await resolveFixture(
        'reactive_creation_in_build_valid.dart',
      );
      expect(countOffenses(result.unit), 0);
    });
  });
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this._checker, this._finder, this._onOffense);

  final AllObserverTypeChecker _checker;
  final RebuildScopeFinder _finder;
  final void Function() _onOffense;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final isReactive =
        _checker.isObservableCreation(node) ||
        _checker.isComputedCreation(node) ||
        _checker.isObservableFutureCreation(node) ||
        _checker.isObservableStreamCreation(node);
    if (isReactive && _finder.isInsideRebuildScope(node)) _onOffense();
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (_checker.isObsExtensionAccess(node) &&
        _finder.isInsideRebuildScope(node)) {
      _onOffense();
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (_checker.isObsExtensionAccess(node) &&
        _finder.isInsideRebuildScope(node)) {
      _onOffense();
    }
    super.visitPrefixedIdentifier(node);
  }
}
