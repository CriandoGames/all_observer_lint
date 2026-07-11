import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';

/// `prefer_computed_for_derived_state` (strict, `info`, experimental)
///
/// Flags an observable that is assigned a value derived purely from other
/// observables' `.value` — a manual re-derivation that `Computed` already
/// solves declaratively.
///
/// Deliberately narrow to control false positives: only a plain (`=`)
/// assignment to `<field>.value` is considered, and only when the
/// right-hand side reads at least one *other* observable's `.value` and
/// never reads the assigned field's own `.value` (which would suggest
/// accumulation, not pure derivation). Not included in `recommended`.
///
/// See `documentation/en/rules/prefer_computed_for_derived_state.md`.
class PreferComputedForDerivedState extends DartLintRule {
  PreferComputedForDerivedState({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'prefer_computed_for_derived_state';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.preferComputedForDerivedState,
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

    context.registry.addAssignmentExpression((node) {
      if (node.operator.lexeme != '=') return;

      final targetName = _observableValueTargetName(node.leftHandSide, checker);
      if (targetName == null) return;

      final otherReads = <String>{};
      var readsOwnValue = false;
      node.rightHandSide.accept(
        _ValueReadCollector(
          checker: checker,
          onRead: (name) {
            if (name == targetName) {
              readsOwnValue = true;
            } else {
              otherReads.add(name);
            }
          },
        ),
      );

      if (!readsOwnValue && otherReads.isNotEmpty) {
        reporter.atNode(node, code);
      }
    });
  }

  String? _observableValueTargetName(
    Expression expression,
    AllObserverTypeChecker checker,
  ) {
    Expression? target;
    String? propertyName;
    String? targetName;
    if (expression is PropertyAccess) {
      target = expression.target;
      propertyName = expression.propertyName.name;
      if (target is SimpleIdentifier) targetName = target.name;
    } else if (expression is PrefixedIdentifier) {
      target = expression.prefix;
      propertyName = expression.identifier.name;
      targetName = expression.prefix.name;
    }
    if (target == null || propertyName != 'value' || targetName == null) {
      return null;
    }
    if (!checker.isObservableType(target.staticType)) return null;
    return targetName;
  }
}

class _ValueReadCollector extends RecursiveAstVisitor<void> {
  _ValueReadCollector({required this.checker, required this.onRead});

  final AllObserverTypeChecker checker;
  final void Function(String name) onRead;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _maybeReport(node.target, node.propertyName.name);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _maybeReport(node.prefix, node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }

  void _maybeReport(Expression? target, String propertyName) {
    if (target is! SimpleIdentifier || propertyName != 'value') return;
    final type = target.staticType;
    if (checker.isObservableType(type) || checker.isComputedType(type)) {
      onRead(target.name);
    }
  }
}
