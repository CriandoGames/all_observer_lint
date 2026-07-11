import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/build_context_detector.dart';

/// `avoid_reactive_creation_in_build`
///
/// Flags `Observable`/`.obs`, `Computed`, `ObservableFuture`, and
/// `ObservableStream` created directly inside a widget's `build` method or
/// an `Observer` callback. Both re-run on every rebuild, so a resource
/// created there is silently recreated (and its previous state/subscribers
/// discarded) each time.
///
/// See `documentation/en/rules/avoid_reactive_creation_in_build.md`.
class AvoidReactiveCreationInBuild extends DartLintRule {
  AvoidReactiveCreationInBuild({required CustomLintConfigs configs})
      : super(code: _buildCode(configs));

  static const ruleName = 'avoid_reactive_creation_in_build';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage:
          messages.message(DiagnosticMessageKey.reactiveCreationInsideBuild),
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

    context.registry.addInstanceCreationExpression((node) {
      final isReactiveCreation = checker.isObservableCreation(node) ||
          checker.isComputedCreation(node) ||
          checker.isObservableFutureCreation(node) ||
          checker.isObservableStreamCreation(node);
      if (isReactiveCreation && finder.isInsideRebuildScope(node)) {
        reporter.atNode(node, code);
      }
    });

    void checkObsAccess(Expression node) {
      if (checker.isObsExtensionAccess(node) &&
          finder.isInsideRebuildScope(node)) {
        reporter.atNode(node, code);
      }
    }

    context.registry.addPropertyAccess(checkObsAccess);
    context.registry.addPrefixedIdentifier(checkObsAccess);
  }
}
