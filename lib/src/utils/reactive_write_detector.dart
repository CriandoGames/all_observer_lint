import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'all_observer_type_checker.dart';

/// Describes a single reactive-write occurrence found by
/// [ReactiveWriteDetector].
class ReactiveWriteOccurrence {
  const ReactiveWriteOccurrence(this.node, this.description);

  /// The smallest AST node representing the offending write (used for the
  /// diagnostic's source range).
  final AstNode node;

  /// A short, human-readable description of what kind of write this is
  /// (e.g. "assignment to .value"), useful for tests and for building
  /// richer messages later.
  final String description;
}

/// Finds direct writes to `all_observer` reactive values within a subtree.
///
/// "Direct" is intentional and conservative: this detector recognizes
/// `x.value = ...`, `x.value++`, `x.value--`, and compound assignments like
/// `x.value += 1` where `x`'s static type is `Observable`/`Computed`. It
/// deliberately does not attempt to detect indirect mutation through
/// aliases, reactive collection mutation (`list.add(...)`), or mutation
/// through helper methods, to keep the false-positive rate low. Expanding
/// coverage is tracked in `documentation/backlog.md`.
///
/// The walk stops at nested function boundaries by default (see
/// [includeNestedFunctions]), because a write inside a nested closure does
/// not necessarily execute as part of the immediate callback body (e.g. a
/// write scheduled with `Future(() => ...)`).
class ReactiveWriteDetector {
  const ReactiveWriteDetector(this._checker);

  final AllObserverTypeChecker _checker;

  List<ReactiveWriteOccurrence> findIn(
    AstNode root, {
    bool includeNestedFunctions = false,
  }) {
    final visitor = _ReactiveWriteVisitor(
      checker: _checker,
      includeNestedFunctions: includeNestedFunctions,
      root: root,
    );
    root.visitChildren(visitor);
    return visitor.occurrences;
  }
}

class _ReactiveWriteVisitor extends RecursiveAstVisitor<void> {
  _ReactiveWriteVisitor({
    required AllObserverTypeChecker checker,
    required this.includeNestedFunctions,
    required this.root,
  }) : _checker = checker;

  final AllObserverTypeChecker _checker;
  final bool includeNestedFunctions;
  final AstNode root;
  final List<ReactiveWriteOccurrence> occurrences = [];

  bool _isReactiveValueAccess(Expression expression) {
    Expression? target;
    String? propertyName;
    if (expression is PropertyAccess) {
      target = expression.target;
      propertyName = expression.propertyName.name;
    } else if (expression is PrefixedIdentifier) {
      target = expression.prefix;
      propertyName = expression.identifier.name;
    }
    if (target == null || propertyName != 'value') return false;
    final targetType = target.staticType;
    return _checker.isObservableType(targetType) ||
        _checker.isComputedType(targetType);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (!includeNestedFunctions && node != root) {
      // Stop descending into nested closures.
      return;
    }
    super.visitFunctionExpression(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (_isReactiveValueAccess(node.leftHandSide)) {
      occurrences.add(
        ReactiveWriteOccurrence(node, 'assignment to .value'),
      );
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if ((node.operator.lexeme == '++' || node.operator.lexeme == '--') &&
        _isReactiveValueAccess(node.operand)) {
      occurrences.add(
        ReactiveWriteOccurrence(node, 'increment/decrement of .value'),
      );
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if ((node.operator.lexeme == '++' || node.operator.lexeme == '--') &&
        _isReactiveValueAccess(node.operand)) {
      occurrences.add(
        ReactiveWriteOccurrence(node, 'increment/decrement of .value'),
      );
    }
    super.visitPrefixExpression(node);
  }
}
