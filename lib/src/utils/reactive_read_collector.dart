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
    if (node != primaryClosure) {
      // A nested closure (e.g. the callback passed to `.map(...)` inside a
      // tracking scope) is a boundary for *counting* reads here, but its
      // body may still execute synchronously as part of this scope and
      // read a reactive value we are not analyzing. For the assist (which
      // never sets flagPotentialHiddenReads) this stays a hard boundary:
      // only closures reachable from event handlers etc. matter there, and
      // being conservative would make the assist too shy to ever fire. For
      // the empty-tracking-scope rules, though, silently ignoring nested
      // closures risks a false "no reads at all" diagnostic, so flag it as
      // a potential hidden read instead of asserting there is none.
      if (flagPotentialHiddenReads) hasPotentialHiddenRead = true;
      return;
    }
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
    if (flagPotentialHiddenReads && _mayHideReactiveRead(node)) {
      hasPotentialHiddenRead = true;
    }
    super.visitMethodInvocation(node);
  }

  /// Whether [node] invokes something whose body we have not analyzed and
  /// that could plausibly read a reactive value internally: a bare helper
  /// (`helper()`), a call through `this`/an instance target
  /// (`this.helper()`, `controller.calculate()`), or a static helper
  /// (`Helpers.calculate()`).
  ///
  /// Deliberately excluded, so the empty-tracking-scope rules stay useful
  /// rather than going silent on everything: calls resolved to
  /// `all_observer` itself (already understood via [checker]) and calls
  /// resolved to the Dart core SDK (`dart:core`, `dart:async`, etc. —
  /// `toString()`, `hashCode`, `Future.then`, and similar cannot reach back
  /// into the app's reactive state).
  bool _mayHideReactiveRead(MethodInvocation node) {
    final element = node.methodName.element;
    if (checker.isAllObserverElement(element)) return false;
    final libraryUri = element?.library?.identifier;
    if (libraryUri != null && libraryUri.startsWith('dart:')) return false;
    return true;
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
