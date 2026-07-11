import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/reactive_write_detector.dart';

/// `avoid_reactive_write_in_computed`
///
/// Flags a direct write to a reactive value (`x.value = ...`,
/// `x.value++`/`--`, or a compound assignment on `.value`) inside a
/// `Computed` derivation callback.
///
/// This rule is the narrow, evidence-oriented replacement for a broad
/// "no side effects in Computed" rule: it only recognizes the specific,
/// unambiguous write forms handled by [ReactiveWriteDetector], which keeps
/// the false-positive rate low enough to test and, eventually, propose for
/// promotion to `error` once a reproducible failure is demonstrated against
/// the `all_observer` engine (see `documentation/backlog.md`,
/// "self_referencing_computed" / "observable_write_during_computed").
/// Until that proof exists, this rule stays at `warning`.
///
/// See `documentation/en/rules/avoid_reactive_write_in_computed.md`.
class AvoidReactiveWriteInComputed extends DartLintRule {
  AvoidReactiveWriteInComputed({required CustomLintConfigs configs})
      : super(code: _buildCode(configs));

  static const ruleName = 'avoid_reactive_write_in_computed';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.reactiveWriteInsideComputed,
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
    const checker = AllObserverTypeChecker();
    const writeDetector = ReactiveWriteDetector(checker);

    context.registry.addInstanceCreationExpression((node) {
      if (!checker.isComputedCreation(node)) return;

      final callback = _firstFunctionArgument(node);
      if (callback == null) return;

      for (final occurrence in writeDetector.findIn(
        callback,
        includeNestedFunctions: true,
      )) {
        reporter.atNode(occurrence.node, code);
      }
    });
  }

  FunctionExpression? _firstFunctionArgument(InstanceCreationExpression node) {
    for (final argument in node.argumentList.arguments) {
      final value =
          argument is NamedExpression ? argument.expression : argument;
      if (value is FunctionExpression) return value;
    }
    return null;
  }
}
