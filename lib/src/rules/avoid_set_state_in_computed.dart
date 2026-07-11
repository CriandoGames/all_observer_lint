import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/computed_callback_finder.dart';

/// `avoid_set_state_in_computed`
///
/// Flags `setState(...)` called inside a `Computed` derivation callback.
/// `Computed` callbacks can run outside the widget lifecycle (e.g. during
/// dependency tracking triggered by an unrelated `Observer`), so touching
/// widget state directly from one is unsafe regardless of whether it
/// provably crashes in every case.
///
/// See `documentation/en/rules/avoid_set_state_in_computed.md`.
class AvoidSetStateInComputed extends DartLintRule {
  AvoidSetStateInComputed({required CustomLintConfigs configs})
      : super(code: _buildCode(configs));

  static const ruleName = 'avoid_set_state_in_computed';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage:
          messages.message(DiagnosticMessageKey.setStateInsideComputed),
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
    const finder = ComputedCallbackFinder(checker);

    context.registry.addMethodInvocation((node) {
      if (checker.isSetStateInvocation(node) &&
          finder.isInsideComputedCallback(node)) {
        reporter.atNode(node, code);
      }
    });
  }
}
