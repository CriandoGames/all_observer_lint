// ignore_for_file: experimental_member_use

import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

void main() {
  const checker = AllObserverTypeChecker();

  int countOffenses(CompilationUnit unit) {
    var count = 0;
    unit.accept(_Visitor(checker, () => count++));
    return count;
  }

  group('prefer_assign_all_for_reactive_list_replace', () {
    test(
      'flags clear followed by add/addAll on the same reactive list',
      () async {
        final result = await resolveFixture(
          'reactive_list_replace_invalid.dart',
        );
        expect(countOffenses(result.unit), 3);
      },
    );

    test(
      'does not flag assignAll, clear-only, non-reactive, or non-immediate',
      () async {
        final result = await resolveFixture('reactive_list_replace_valid.dart');
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
  void visitBlock(Block node) {
    final statements = node.statements;
    for (var index = 0; index < statements.length - 1; index++) {
      final clearTarget = _reactiveListMethodTarget(
        statements[index],
        methodName: 'clear',
      );
      if (clearTarget == null) continue;

      final addTarget = _reactiveListMethodTarget(
        statements[index + 1],
        methodName: 'add',
        alternativeMethodName: 'addAll',
      );
      if (addTarget == null) continue;
      if (_sameTarget(clearTarget, addTarget)) _onOffense();
    }
    super.visitBlock(node);
  }

  _Target? _reactiveListMethodTarget(
    Statement statement, {
    required String methodName,
    String? alternativeMethodName,
  }) {
    if (statement is! ExpressionStatement) return null;
    final expression = statement.expression;
    if (expression is! MethodInvocation) return null;
    final name = expression.methodName.name;
    if (name != methodName && name != alternativeMethodName) return null;

    final target = expression.target;
    if (target == null || !_checker.isObservableListType(target.staticType)) {
      return null;
    }

    return _Target.fromExpression(target);
  }
}

class _Target {
  const _Target(this.element, this.text);

  final Element? element;
  final String text;

  static _Target fromExpression(Expression expression) {
    return _Target(_targetElement(expression), expression.toSource());
  }
}

Element? _targetElement(Expression expression) {
  if (expression is SimpleIdentifier) {
    return _canonicalElement(expression.element);
  }
  if (expression is PropertyAccess && expression.target is ThisExpression) {
    return _canonicalElement(expression.propertyName.element);
  }
  if (expression is PrefixedIdentifier) {
    return _canonicalElement(expression.element);
  }
  return null;
}

Element? _canonicalElement(Element? element) {
  if (element == null) return null;
  if (element is PropertyAccessorElement) {
    return element.variable?.baseElement ?? element.baseElement;
  }
  return element.baseElement;
}

bool _sameTarget(_Target left, _Target right) {
  if (left.element != null && right.element != null) {
    return left.element == right.element;
  }
  return left.text == right.text;
}
