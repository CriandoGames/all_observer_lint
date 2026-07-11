// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/build_context_detector.dart';

/// `unobserved_reactive_read_in_build` (strict, `info`)
///
/// Flags `.value` reads of reactive state directly inside a widget `build`
/// method when they are not inside an `Observer` callback. Such reads render a
/// snapshot but do not subscribe the UI to future changes.
class UnobservedReactiveReadInBuild extends DartLintRule {
  UnobservedReactiveReadInBuild({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'unobserved_reactive_read_in_build';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.unobservedReactiveReadInBuild,
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
    final finder = RebuildScopeFinder(checker);

    context.registry.addPrefixedIdentifier((node) {
      if (!_isReactiveValueRead(node, node.prefix, checker)) return;
      if (!_isDirectlyInsideWidgetBuild(node, finder)) return;
      reporter.atNode(node, code);
    });

    context.registry.addPropertyAccess((node) {
      if (!_isReactiveValueRead(node, node.target, checker)) return;
      if (!_isDirectlyInsideWidgetBuild(node, finder)) return;
      reporter.atNode(node, code);
    });
  }
}

bool _isReactiveValueRead(
  Expression expression,
  Expression? target,
  AllObserverTypeChecker checker,
) {
  if (_isWrite(expression)) return false;

  String? propertyName;
  if (expression is PrefixedIdentifier) {
    propertyName = expression.identifier.name;
  } else if (expression is PropertyAccess) {
    propertyName = expression.propertyName.name;
  }
  if (propertyName != 'value') return false;

  final targetType = target?.staticType;
  return checker.isObservableType(targetType) ||
      checker.isComputedType(targetType) ||
      checker.isObservableListType(targetType);
}

bool _isWrite(Expression expression) {
  final parent = expression.parent;
  if (parent is AssignmentExpression &&
      identical(parent.leftHandSide, expression)) {
    return true;
  }
  if (parent is PrefixExpression && identical(parent.operand, expression)) {
    return parent.operator.lexeme == '++' || parent.operator.lexeme == '--';
  }
  if (parent is PostfixExpression && identical(parent.operand, expression)) {
    return parent.operator.lexeme == '++' || parent.operator.lexeme == '--';
  }
  return false;
}

bool _isDirectlyInsideWidgetBuild(AstNode node, RebuildScopeFinder finder) {
  final scope = finder.find(node);
  return scope is MethodDeclaration && scope.name.lexeme == 'build';
}
