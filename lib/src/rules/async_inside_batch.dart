import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';

class AsyncInsideBatch extends DartLintRule {
  AsyncInsideBatch({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'async_inside_batch';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(DiagnosticMessageKey.asyncInsideBatch),
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
    context.registry.addMethodInvocation((node) {
      if (!checker.isBatchInvocation(node)) return;
      for (final argument in node.argumentList.arguments) {
        final value = argument is NamedExpression
            ? argument.expression
            : argument;
        if (value is FunctionExpression && value.body.isAsynchronous) {
          reporter.atNode(value, code);
          return;
        }
        final element = switch (value) {
          SimpleIdentifier(:final element) => element,
          PrefixedIdentifier(:final identifier) => identifier.element,
          PropertyAccess(:final propertyName) => propertyName.element,
          _ => null,
        };
        if (element is ExecutableElement &&
            element.firstFragment.isAsynchronous) {
          reporter.atNode(value, code);
          return;
        }
      }
    });
  }
}

// ignore_for_file: experimental_member_use
