// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import 'all_observer_type_checker.dart';

class ReactiveReadOccurrence {
  const ReactiveReadOccurrence(this.node, this.element);

  final Expression node;
  final Element? element;
}

class ReactiveReadResult {
  const ReactiveReadResult({
    required this.reads,
    required this.hasWatchRead,
    required this.hasUnresolvedNode,
    required this.hasPotentialHiddenRead,
  });

  final List<ReactiveReadOccurrence> reads;
  final bool hasWatchRead;
  final bool hasUnresolvedNode;
  final bool hasPotentialHiddenRead;
}

/// Collects statically resolved immediate reactive reads.
///
/// Deferred nested closures are boundaries by default. `peek()` and
/// `untracked(...)` are intentionally excluded because they do not register a
/// dependency in the surrounding tracking scope.
class ReactiveReadCollector {
  const ReactiveReadCollector(this._checker);

  final AllObserverTypeChecker _checker;

  ReactiveReadResult collect(
    AstNode root, {
    FunctionExpression? primaryClosure,
    bool flagPotentialHiddenReads = false,
  }) {
    final visitor = _ReactiveReadVisitor(
      checker: _checker,
      primaryClosure: primaryClosure,
      flagPotentialHiddenReads: flagPotentialHiddenReads,
    );
    root.accept(visitor);
    return ReactiveReadResult(
      reads: visitor.reads,
      hasWatchRead: visitor.hasWatchRead,
      hasUnresolvedNode: visitor.hasUnresolvedNode,
      hasPotentialHiddenRead: visitor.hasPotentialHiddenRead,
    );
  }
}

class _ReactiveReadVisitor extends RecursiveAstVisitor<void> {
  _ReactiveReadVisitor({
    required this.checker,
    required this.primaryClosure,
    required this.flagPotentialHiddenReads,
  });

  final AllObserverTypeChecker checker;
  final FunctionExpression? primaryClosure;
  final bool flagPotentialHiddenReads;
  final List<ReactiveReadOccurrence> reads = [];
  bool hasWatchRead = false;
  bool hasUnresolvedNode = false;
  bool hasPotentialHiddenRead = false;

  static const _collectionReadProperties = {
    'length',
    'isEmpty',
    'isNotEmpty',
    'first',
    'last',
    'single',
  };

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node != primaryClosure) return;
    super.visitFunctionExpression(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {}

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (checker.isWatchInvocation(node)) {
      hasWatchRead = true;
      return;
    }
    if (checker.isUntrackedInvocation(node)) return;
    if (checker.isPeekInvocation(node)) return;

    if (node.methodName.element == null) hasUnresolvedNode = true;
    if (flagPotentialHiddenReads &&
        node.target == null &&
        !checker.isAllObserverElement(node.methodName.element)) {
      hasPotentialHiddenRead = true;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _recordValueRead(node, node.prefix, node.identifier.element);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _recordValueRead(node, node.target, node.propertyName.element);
    super.visitPropertyAccess(node);
  }

  void _recordValueRead(Expression node, Expression? target, Element? element) {
    if (target == null) return;
    final name = switch (node) {
      PrefixedIdentifier(:final identifier) => identifier.name,
      PropertyAccess(:final propertyName) => propertyName.name,
      _ => null,
    };
    if (_isWrite(node)) return;
    final targetType = target.staticType;
    final isValueRead =
        name == 'value' && checker.isReactiveValueType(targetType);
    final isCollectionRead =
        name != null &&
        _collectionReadProperties.contains(name) &&
        (checker.isObservableListType(targetType) ||
            checker.isObservableMapType(targetType) ||
            checker.isObservableSetType(targetType));
    if (!isValueRead && !isCollectionRead) return;
    if (element == null) {
      hasUnresolvedNode = true;
      return;
    }
    reads.add(ReactiveReadOccurrence(node, element));
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    if (!_isWrite(node)) {
      final targetType = node.target?.staticType;
      if (checker.isObservableListType(targetType) ||
          checker.isObservableMapType(targetType)) {
        final element = node.element;
        if (element == null) {
          hasUnresolvedNode = true;
        } else {
          reads.add(ReactiveReadOccurrence(node, element));
        }
      }
    }
    super.visitIndexExpression(node);
  }
}

bool _isWrite(Expression expression) {
  final parent = expression.parent;
  if (parent is AssignmentExpression &&
      identical(parent.leftHandSide, expression)) {
    return true;
  }
  if (parent is PrefixExpression && identical(parent.operand, expression)) {
    return parent.operator.lexeme == '++' || parent.operator.lexeme == '--';
  }
  if (parent is PostfixExpression && identical(parent.operand, expression)) {
    return parent.operator.lexeme == '++' || parent.operator.lexeme == '--';
  }
  return false;
}
