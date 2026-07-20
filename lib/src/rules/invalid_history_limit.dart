import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';

class InvalidHistoryLimit extends DartLintRule {
  InvalidHistoryLimit({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'invalid_history_limit';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.invalidHistoryLimit,
      ),
      errorSeverity: ErrorSeverity.WARNING,
    );
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final checker = AllObserverTypeChecker();

    void check(ArgumentList arguments) {
      final limit = _namedArgument(arguments, 'limit');
      if (limit == null) return;
      final value = limit.computeConstantValue()?.value?.toIntValue();
      if (value != null && value <= 0) reporter.atNode(limit, code);
    }

    context.registry.addMethodInvocation((node) {
      if (checker.isWithHistoryInvocation(node)) check(node.argumentList);
    });
    context.registry.addInstanceCreationExpression((node) {
      if (checker.isObservableHistoryCreation(node)) check(node.argumentList);
    });
  }
}

Expression? _namedArgument(ArgumentList arguments, String name) {
  for (final argument in arguments.arguments.whereType<NamedExpression>()) {
    if (argument.name.label.name == name) return argument.expression;
  }
  return null;
}
