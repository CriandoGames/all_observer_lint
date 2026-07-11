import 'package:analyzer/dart/ast/ast.dart';

import 'all_observer_type_checker.dart';

/// Shared helper to find the "rebuild scope" a given AST node lives in, if
/// any. Used by `avoid_reactive_creation_in_build`,
/// `avoid_effect_creation_in_build`, and `watch_only_inside_build`.
///
/// A rebuild scope is either:
///  * a Flutter widget `build(BuildContext context)` method, or
///  * the callback passed to `Observer(...)`.
///
/// Both re-execute every time the corresponding widget rebuilds/notifies,
/// so creating reactive resources or effects directly inside them recreates
/// those resources on every rebuild.
///
/// Walking stops (returns `null`) at the first unrelated closure or method
/// boundary, so code inside event handlers (`onPressed: () { ... }`) that
/// merely happen to be declared inside `build` is never flagged — that
/// closure only runs when the event fires, not on every rebuild.
class RebuildScopeFinder {
  const RebuildScopeFinder(this._checker);

  final AllObserverTypeChecker _checker;

  /// Returns the nearest enclosing rebuild-scope node for [node], or `null`
  /// if [node] is not (directly) inside one.
  AstNode? find(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration && _isWidgetBuildMethod(current)) {
        return current;
      }
      if (current is FunctionExpression) {
        final parent = current.parent;
        final invocation = parent is ArgumentList ? parent.parent : parent;
        if (invocation is InstanceCreationExpression &&
            _checker.isObserverWidgetCreation(invocation)) {
          return current;
        }
        // Any other closure is a scope boundary: code inside it does not
        // necessarily run on every rebuild (e.g. event handlers, one-shot
        // callbacks passed to Future.then, etc).
        return null;
      }
      if (current is FunctionDeclaration || current is MethodDeclaration) {
        return null;
      }
      current = current.parent;
    }
    return null;
  }

  /// Whether [node] is directly inside a rebuild scope (see [find]).
  bool isInsideRebuildScope(AstNode node) => find(node) != null;

  /// Like [find], but only matches an `Observer(...)` callback, not a
  /// widget `build` method. Used by
  /// `avoid_observable_write_during_observer_build`, which is specifically
  /// about `Observer`'s rendering contract.
  FunctionExpression? findObserverScope(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionExpression) {
        final parent = current.parent;
        final invocation = parent is ArgumentList ? parent.parent : parent;
        if (invocation is InstanceCreationExpression &&
            _checker.isObserverWidgetCreation(invocation)) {
          return current;
        }
        return null;
      }
      if (current is FunctionDeclaration || current is MethodDeclaration) {
        return null;
      }
      current = current.parent;
    }
    return null;
  }

  bool _isWidgetBuildMethod(MethodDeclaration method) {
    if (method.name.lexeme != 'build') return false;
    final parameters = method.parameters?.parameters;
    if (parameters == null || parameters.length != 1) return false;

    final paramElement = parameters.first.declaredElement;
    final paramType = paramElement?.type;
    if (paramType?.element?.name != 'BuildContext') return false;
    if (!_checker.isFlutterFrameworkElement(paramType!.element)) return false;

    final returnType = method.declaredElement?.returnType;
    if (returnType?.element?.name != 'Widget') return false;
    return _checker.isFlutterFrameworkElement(returnType!.element);
  }
}
