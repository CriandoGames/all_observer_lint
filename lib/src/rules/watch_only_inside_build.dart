import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/build_context_detector.dart';

/// `watch_only_inside_build`
///
/// Flags `watch(context)` calls made outside a recognized widget build
/// context. This rule is intentionally conservative: it only reports when
/// it can positively prove the call sits inside a *different*, unrelated
/// closure/method than any build scope on the way up (see
/// [RebuildScopeFinder]). If the enclosing scope can't be determined with
/// confidence, no diagnostic is emitted.
///
/// See `documentation/en/rules/watch_only_inside_build.md`.
class WatchOnlyInsideBuild extends DartLintRule {
  WatchOnlyInsideBuild({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'watch_only_inside_build';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.invalidWatchContext,
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
      if (!checker.isWatchInvocation(node)) return;

      // Conservative: only flag when we can prove there is an enclosing
      // method/function boundary that is clearly not a build scope. A bare
      // top-level/local function that itself takes a BuildContext (e.g. a
      // small helper called from build) is ambiguous, so we don't flag it.
      final boundary = _enclosingExecutableBoundary(node);
      if (boundary == null) return;
      if (finder.isInsideRebuildScope(node)) return;
      if (_looksAmbiguous(boundary)) return;

      reporter.atNode(node, code);
    });
  }

  /// The nearest enclosing function/method body, or `null` if none (e.g.
  /// top-level initializer, which we don't attempt to classify).
  MethodDeclaration? _enclosingExecutableBoundary(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) return current;
      if (current is FunctionExpression || current is FunctionDeclaration) {
        // Local/anonymous functions are ambiguous; be conservative.
        return null;
      }
      current = current.parent;
    }
    return null;
  }

  /// A method is "ambiguous" (and thus skipped) if it accepts a
  /// `BuildContext` parameter but is not named `build` — it could
  /// legitimately be called only from within a build context.
  bool _looksAmbiguous(MethodDeclaration method) {
    if (method.name.lexeme == 'build') return false;
    final parameters = method.parameters?.parameters ?? const [];
    for (final parameter in parameters) {
      if (parameter.declaredFragment?.element.type.element?.name ==
          'BuildContext') {
        return true;
      }
    }
    return false;
  }
}
