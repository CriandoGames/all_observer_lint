import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';

/// `prefer_assign_all_for_reactive_list_replace` (strict, `info`)
///
/// Flags immediate `ObservableList.clear()` followed by `add(...)` or
/// `addAll(...)` on the same list. For full replacement, `assign(...)` and
/// `assignAll(...)` express the intent and notify once.
class PreferAssignAllForReactiveListReplace extends DartLintRule {
  PreferAssignAllForReactiveListReplace({required CustomLintConfigs configs})
      : super(code: _buildCode(configs));

  static const ruleName = 'prefer_assign_all_for_reactive_list_replace';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.preferAssignAllForReactiveListReplace,
      ),
      errorSeverity: ErrorSeverity.INFO,
    );
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    const checker = AllObserverTypeChecker();

    context.registry.addBlock((block) {
      final statements = block.statements;
      for (var index = 0; index < statements.length - 1; index++) {
        final clearTarget = _reactiveListMethodTarget(
          statements[index],
          checker,
          methodName: 'clear',
        );
        if (clearTarget == null) continue;

        final addTarget = _reactiveListMethodTarget(
          statements[index + 1],
          checker,
          methodName: 'add',
          alternativeMethodName: 'addAll',
        );
        if (addTarget == null) continue;
        if (!_sameTarget(clearTarget, addTarget)) continue;

        reporter.atNode(statements[index], code);
      }
    });
  }

  _Target? _reactiveListMethodTarget(
    Statement statement,
    AllObserverTypeChecker checker, {
    required String methodName,
    String? alternativeMethodName,
  }) {
    if (statement is! ExpressionStatement) return null;
    final expression = statement.expression;
    if (expression is! MethodInvocation) return null;
    final name = expression.methodName.name;
    if (name != methodName && name != alternativeMethodName) return null;

    final target = expression.target;
    if (target == null || !checker.isObservableListType(target.staticType)) {
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
    return _canonicalElement(expression.staticElement);
  }
  if (expression is PropertyAccess && expression.target is ThisExpression) {
    return _canonicalElement(expression.propertyName.staticElement);
  }
  if (expression is PrefixedIdentifier) {
    return _canonicalElement(expression.staticElement);
  }
  return null;
}

Element? _canonicalElement(Element? element) {
  if (element is PropertyAccessorElement) return element.variable2;
  return element;
}

bool _sameTarget(_Target left, _Target right) {
  if (left.element != null && right.element != null) {
    return left.element == right.element;
  }
  return left.text == right.text;
}
