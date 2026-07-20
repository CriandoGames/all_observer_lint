import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/reactive_write_detector.dart';

/// `avoid_observable_write_during_observer_build`
///
/// Flags a direct reactive write (`x.value = ...`, `x.value++`/`--`, or a
/// compound assignment on `.value`) inside an `Observer(...)` rendering
/// callback.
///
/// Severity note: this rule stays at `warning`, not `error`. An
/// unconditional write to a dependency the same `Observer` reads is a
/// strong candidate for a proven reactive cycle and may be split out into a
/// separate, stricter `unconditional_reactive_write_during_observer_build`
/// diagnostic once that failure is reproduced against the `all_observer`
/// engine (see `documentation/backlog.md`). A conditional write, or a write
/// to an observable the callback does not itself read, is architecturally
/// questionable but not proven to crash — bundling every case into one
/// `error` rule would violate the project's "blocking rules require proof"
/// policy.
///
/// See
/// `documentation/en/rules/avoid_observable_write_during_observer_build.md`.
class AvoidObservableWriteDuringObserverBuild extends DartLintRule {
  AvoidObservableWriteDuringObserverBuild({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'avoid_observable_write_during_observer_build';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.observableWriteDuringObserverBuild,
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
    final writeDetector = ReactiveWriteDetector(checker);

    context.registry.addInstanceCreationExpression((node) {
      if (!checker.isObserverWidgetCreation(node)) return;

      final callback = _firstFunctionArgument(node);
      if (callback == null) return;

      for (final occurrence in writeDetector.findIn(
        callback,
        includeNestedFunctions: false,
      )) {
        reporter.atNode(occurrence.node, code);
      }
    });
  }

  FunctionExpression? _firstFunctionArgument(InstanceCreationExpression node) {
    for (final argument in node.argumentList.arguments) {
      final value = argument is NamedExpression
          ? argument.expression
          : argument;
      if (value is FunctionExpression) return value;
    }
    return null;
  }
}
