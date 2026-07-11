import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/self_referencing_computed_detector.dart';

/// `self_referencing_computed`
///
/// Flags a direct reactive cycle where a `Computed` reads its own `.value`
/// inside its derivation callback.
///
/// See `documentation/en/rules/self_referencing_computed.md`.
class SelfReferencingComputed extends DartLintRule {
  SelfReferencingComputed({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'self_referencing_computed';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.selfReferencingComputed,
      ),
      errorSeverity: ErrorSeverity.ERROR,
    );
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    const checker = AllObserverTypeChecker();
    const detector = SelfReferencingComputedDetector(checker);

    context.registry.addInstanceCreationExpression((node) {
      if (detector.isSelfReferencingComputed(node)) {
        reporter.atNode(node, code);
      }
    });
  }
}
