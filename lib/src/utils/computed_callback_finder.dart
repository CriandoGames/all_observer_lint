import 'package:analyzer/dart/ast/ast.dart';

import 'all_observer_type_checker.dart';

/// Finds the nearest enclosing `Computed(...)` derivation callback for a
/// given AST node, if any.
///
/// Unlike [RebuildScopeFinder] (build/`Observer` detection), this walk
/// intentionally *does* cross nested closure boundaries: any function
/// literal declared textually inside the `Computed` callback is still
/// considered part of it (e.g. `items.map((i) => ...)`), because it is
/// reasonable for a derivation to use synchronous, purely-functional
/// nested closures. The walk still stops at a named function/method
/// boundary, since a `Computed` cannot "contain" another declared method.
///
/// Known limitation: a closure that is genuinely deferred (e.g. passed to
/// `Future(...).then(...)`) is textually nested but does not run
/// synchronously as part of the derivation. This finder does not
/// distinguish that case; see `documentation/backlog.md`.
class ComputedCallbackFinder {
  const ComputedCallbackFinder(this._checker);

  final AllObserverTypeChecker _checker;

  FunctionExpression? find(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionExpression &&
          _isComputedCallbackArgument(current)) {
        return current;
      }
      if (current is FunctionDeclaration || current is MethodDeclaration) {
        return null;
      }
      current = current.parent;
    }
    return null;
  }

  bool isInsideComputedCallback(AstNode node) => find(node) != null;

  bool _isComputedCallbackArgument(FunctionExpression function) {
    AstNode? parent = function.parent;
    if (parent is NamedExpression) parent = parent.parent;
    if (parent is! ArgumentList) return false;
    final creation = parent.parent;
    return creation is InstanceCreationExpression &&
        _checker.isComputedCreation(creation);
  }
}
