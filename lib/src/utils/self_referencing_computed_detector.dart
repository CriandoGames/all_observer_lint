import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import 'all_observer_type_checker.dart';

/// Detects a direct reactive cycle where a `Computed` reads its own `.value`.
///
/// The detector is intentionally narrow enough for an error-level rule: it
/// only matches a `Computed(...)` assigned directly to a variable/field and a
/// `.value` read resolved to that same symbol inside the callback.
class SelfReferencingComputedDetector {
  const SelfReferencingComputedDetector(this._checker);

  final AllObserverTypeChecker _checker;

  bool isSelfReferencingComputed(InstanceCreationExpression node) {
    if (!_checker.isComputedCreation(node)) return false;

    final owner = _ownerElement(node);
    if (owner == null) return false;

    final callback = _firstFunctionArgument(node);
    if (callback == null) return false;

    final visitor = _SelfReferenceVisitor(callback: callback, owner: owner);
    callback.body.accept(visitor);
    return visitor.found;
  }

  Element? _ownerElement(InstanceCreationExpression node) {
    final parent = node.parent;
    if (parent is VariableDeclaration && identical(parent.initializer, node)) {
      return _canonicalElement(parent.declaredElement);
    }
    if (parent is AssignmentExpression &&
        identical(parent.rightHandSide, node)) {
      return _canonicalElement(parent.writeElement) ??
          _assignableElement(parent.leftHandSide);
    }
    return null;
  }

  Element? _assignableElement(Expression expression) {
    if (expression is SimpleIdentifier) {
      return _canonicalElement(expression.element);
    }
    if (expression is PropertyAccess && expression.target is ThisExpression) {
      return _canonicalElement(expression.propertyName.element);
    }
    return null;
  }

  FunctionExpression? _firstFunctionArgument(InstanceCreationExpression node) {
    for (final argument in node.argumentList.arguments) {
      final value = argument is NamedExpression
          ? argument.expression
          : argument;
      if (value is FunctionExpression) return value;
    }
    return null;
  }
}

class _SelfReferenceVisitor extends RecursiveAstVisitor<void> {
  _SelfReferenceVisitor({required this.callback, required this.owner});

  final FunctionExpression callback;
  final Element owner;

  bool found = false;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node != callback) return;
    super.visitFunctionExpression(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Local functions are not executed just because the Computed callback runs.
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'value' &&
        _sameElement(node.prefix.element, owner)) {
      found = true;
      return;
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'value' &&
        _sameElement(_targetElement(node.target), owner)) {
      found = true;
      return;
    }
    super.visitPropertyAccess(node);
  }

  Element? _targetElement(Expression? expression) {
    if (expression is SimpleIdentifier) {
      return _canonicalElement(expression.element);
    }
    if (expression is PropertyAccess && expression.target is ThisExpression) {
      return _canonicalElement(expression.propertyName.element);
    }
    return null;
  }
}

Element? _canonicalElement(Element? element) {
  if (element is PropertyAccessorElement) return element.variable;
  return element;
}

bool _sameElement(Element? left, Element right) =>
    _canonicalElement(left) == _canonicalElement(right);
