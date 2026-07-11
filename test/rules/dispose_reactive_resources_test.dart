import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

/// Mirrors `DisposeReactiveResources.run` (see that file) against resolved
/// fixtures.
void main() {
  const checker = AllObserverTypeChecker();

  int countOffenses(CompilationUnit unit) {
    var count = 0;
    unit.accept(_Visitor(checker, () => count++));
    return count;
  }

  group('dispose_reactive_resources', () {
    test('flags workers and ObservableStream fields never disposed', () async {
      final result =
          await resolveFixture('dispose_reactive_resources_invalid.dart');
      expect(countOffenses(result.unit), 2);
    });

    test(
      'does not flag disposed resources, or classes without their own '
      'dispose() (ownership ambiguous)',
      () async {
        final result =
            await resolveFixture('dispose_reactive_resources_valid.dart');
        expect(countOffenses(result.unit), 0);
      },
    );
  });
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this._checker, this._onOffense);

  final AllObserverTypeChecker _checker;
  final void Function() _onOffense;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final disposeMethod = _findDisposeMethod(node);
    if (disposeMethod != null) {
      final disposedNames = _disposedFieldNames(disposeMethod);
      for (final member in node.members) {
        if (member is! FieldDeclaration) continue;
        for (final variable in member.fields.variables) {
          final initializer = variable.initializer;
          if (initializer == null) continue;
          if (!_isDisposableResource(initializer)) continue;
          if (!disposedNames.contains(variable.name.lexeme)) _onOffense();
        }
      }
    }
    super.visitClassDeclaration(node);
  }

  MethodDeclaration? _findDisposeMethod(ClassDeclaration node) {
    for (final member in node.members) {
      if (member is MethodDeclaration &&
          member.name.lexeme == 'dispose' &&
          !member.isStatic) {
        return member;
      }
    }
    return null;
  }

  bool _isDisposableResource(Expression initializer) {
    if (initializer is MethodInvocation) {
      return _checker.isEffectOrWorkerInvocation(initializer);
    }
    if (initializer is InstanceCreationExpression) {
      return _checker.isObservableStreamCreation(initializer);
    }
    return false;
  }

  Set<String> _disposedFieldNames(MethodDeclaration disposeMethod) {
    final names = <String>{};
    final body = disposeMethod.body;
    if (body is! BlockFunctionBody) return names;
    for (final statement in body.block.statements) {
      if (statement is! ExpressionStatement) continue;
      final expression = statement.expression;
      if (expression is! MethodInvocation) continue;
      if (expression.methodName.name != 'dispose') continue;
      final target = expression.target;
      if (target is SimpleIdentifier) names.add(target.name);
    }
    return names;
  }
}
