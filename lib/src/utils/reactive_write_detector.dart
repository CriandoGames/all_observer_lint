import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'all_observer_type_checker.dart';
import 'reactive_collection_operation_classifier.dart';

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
/// "Direct" is intentional and conservative: this detector recognizes:
///
/// - `x.value = ...`, `x.value++`, `x.value--`, and compound assignments
///   like `x.value += 1` where `x`'s static type is `Observable`/`Computed`;
/// - a reactive-collection mutation or wholesale replacement (`list.add(...)`,
///   `list.assignAll(...)`, `map['k'] = v`, `list.length = n`, ...) on an
///   `ObservableList`/`ObservableMap`/`ObservableSet`, classified through
///   [ReactiveCollectionOperationClassifier] — the same classifier used by
///   the reactive-collection rules introduced alongside it, so "is this a
///   mutation" is decided identically everywhere in this package (see
///   `documentation/architecture.md`).
///
/// It deliberately does not attempt to detect indirect mutation through
/// aliases or mutation through helper methods, to keep the false-positive
/// rate low. Expanding coverage further is tracked in
/// `documentation/backlog.md`.
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
  }) : _checker = checker,
       _collectionClassifier = ReactiveCollectionOperationClassifier(checker);

  final AllObserverTypeChecker _checker;
  final ReactiveCollectionOperationClassifier _collectionClassifier;
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

  /// Extracts `(target, propertyName)` from a bare property-access
  /// expression (`target.propertyName`), in either AST shape the analyzer
  /// may produce for it — mirrors [_isReactiveValueAccess]'s own dual-shape
  /// handling, generalized for any property name (used here for
  /// `length =`), not just `value`.
  ({Expression target, String propertyName})? _propertyAccessParts(
    Expression expression,
  ) {
    if (expression is PropertyAccess) {
      final target = expression.target;
      if (target == null) return null;
      return (target: target, propertyName: expression.propertyName.name);
    }
    if (expression is PrefixedIdentifier) {
      return (
        target: expression.prefix,
        propertyName: expression.identifier.name,
      );
    }
    return null;
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
    final lhs = node.leftHandSide;
    if (_isReactiveValueAccess(lhs)) {
      occurrences.add(ReactiveWriteOccurrence(node, 'assignment to .value'));
    } else if (lhs is IndexExpression) {
      // `list[i] = ...` / `map[k] = ...`.
      if (_collectionClassifier.classifyIndexExpression(lhs) ==
          ReactiveCollectionOperationKind.mutation) {
        occurrences.add(
          ReactiveWriteOccurrence(
            node,
            'mutation of reactive collection (index assignment)',
          ),
        );
      }
    } else {
      // `list.length = ...` — the only shared collection property with a
      // public setter (see ReactiveCollectionOperationClassifier).
      final parts = _propertyAccessParts(lhs);
      if (parts != null &&
          _collectionClassifier.classifyPropertyAccess(
                parts.target,
                propertyName: parts.propertyName,
                isWrite: true,
              ) ==
              ReactiveCollectionOperationKind.mutation) {
        occurrences.add(
          ReactiveWriteOccurrence(
            node,
            'mutation of reactive collection (length assignment)',
          ),
        );
      }
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

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final kind = _collectionClassifier.classifyMethodInvocation(node);
    switch (kind) {
      case ReactiveCollectionOperationKind.mutation:
        occurrences.add(
          ReactiveWriteOccurrence(
            node,
            'mutation of reactive collection (${node.methodName.name})',
          ),
        );
      case ReactiveCollectionOperationKind.replacement:
        occurrences.add(
          ReactiveWriteOccurrence(
            node,
            'replacement of reactive collection (${node.methodName.name})',
          ),
        );
      case ReactiveCollectionOperationKind.read:
      case ReactiveCollectionOperationKind.unknown:
        break;
    }
    super.visitMethodInvocation(node);
  }
}
