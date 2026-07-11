import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';

/// `prefer_batch_for_multiple_related_writes` (strict, `info`, experimental)
///
/// Flags three or more consecutive plain assignments to `.value` on
/// different observables within the same block, not already wrapped in
/// `batch(...)`. `all_observer` already coalesces synchronous
/// notifications on its own, so this is a suggestion for cases where
/// external/manual listeners could otherwise observe an inconsistent
/// intermediate state — not a claim that unbatched writes are broken. Not
/// included in `recommended`.
///
/// See
/// `documentation/en/rules/prefer_batch_for_multiple_related_writes.md`.
class PreferBatchForMultipleRelatedWrites extends DartLintRule {
  PreferBatchForMultipleRelatedWrites({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'prefer_batch_for_multiple_related_writes';
  static const int _minimumConsecutiveWrites = 3;

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.preferBatchForMultipleRelatedWrites,
      ),
      errorSeverity: ErrorSeverity.INFO,
    );
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    const checker = AllObserverTypeChecker();

    context.registry.addBlock((block) {
      final statements = block.statements;
      var index = 0;
      while (index < statements.length) {
        final runStart = index;
        while (index < statements.length &&
            _isPlainObservableValueWrite(statements[index], checker)) {
          index++;
        }
        final runLength = index - runStart;
        if (runLength >= _minimumConsecutiveWrites) {
          reporter.atNode(statements[runStart], code);
        }
        if (runLength == 0) index++;
      }
    });
  }

  bool _isPlainObservableValueWrite(
    Statement statement,
    AllObserverTypeChecker checker,
  ) {
    if (statement is! ExpressionStatement) return false;
    final expression = statement.expression;
    if (expression is! AssignmentExpression) return false;
    if (expression.operator.lexeme != '=') return false;

    Expression? target;
    String? propertyName;
    if (expression.leftHandSide is PropertyAccess) {
      final access = expression.leftHandSide as PropertyAccess;
      target = access.target;
      propertyName = access.propertyName.name;
    } else if (expression.leftHandSide is PrefixedIdentifier) {
      final access = expression.leftHandSide as PrefixedIdentifier;
      target = access.prefix;
      propertyName = access.identifier.name;
    }
    if (target == null || propertyName != 'value') return false;
    return checker.isObservableType(target.staticType);
  }
}
