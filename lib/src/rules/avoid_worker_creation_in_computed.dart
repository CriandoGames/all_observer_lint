import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/computed_callback_finder.dart';

/// `avoid_worker_creation_in_computed`
///
/// Flags `effect(...)`, `ever(...)`, `once(...)`, `debounce(...)`, or
/// `interval(...)` registered inside a `Computed` derivation callback.
/// `Computed` can be recomputed multiple times (and its callback re-run
/// speculatively by the dependency tracker), so each recomputation would
/// register a brand-new, never-cleaned-up subscription.
///
/// See `documentation/en/rules/avoid_worker_creation_in_computed.md`.
class AvoidWorkerCreationInComputed extends DartLintRule {
  AvoidWorkerCreationInComputed({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'avoid_worker_creation_in_computed';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.workerCreationInsideComputed,
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
    final finder = ComputedCallbackFinder(checker);

    context.registry.addMethodInvocation((node) {
      if (checker.isEffectOrWorkerInvocation(node) &&
          finder.isInsideComputedCallback(node)) {
        reporter.atNode(node, code);
      }
    });
  }
}
