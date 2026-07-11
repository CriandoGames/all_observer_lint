import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/build_context_detector.dart';

/// `avoid_effect_creation_in_build`
///
/// Flags `effect(...)`, `ever(...)`, `once(...)`, `debounce(...)`, and
/// `interval(...)` registered directly inside a widget's `build` method or
/// an `Observer` callback. Every rebuild would register a brand-new
/// subscription, none of which are automatically cleaned up.
///
/// See `documentation/en/rules/avoid_effect_creation_in_build.md`.
class AvoidEffectCreationInBuild extends DartLintRule {
  AvoidEffectCreationInBuild({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'avoid_effect_creation_in_build';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.effectCreationInsideBuild,
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
    final finder = RebuildScopeFinder(checker);

    context.registry.addMethodInvocation((node) {
      if (checker.isEffectOrWorkerInvocation(node) &&
          finder.isInsideRebuildScope(node)) {
        reporter.atNode(node, code);
      }
    });
  }
}
