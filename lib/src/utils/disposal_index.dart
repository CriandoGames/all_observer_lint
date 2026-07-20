// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import 'reactive_disposal_resolver.dart';

/// A single-pass index of every disposal-shaped call reachable from a
/// class's `dispose()` method, following same-class zero-argument local
/// helper calls (`_disposeResources()`, `this._disposeResources()`) with
/// cycle protection.
///
/// Built once per class (see `dispose_reactive_resources.dart`) instead of
/// re-walking `dispose()` and its helpers once per candidate resource, so
/// the dispose call graph is visited exactly once regardless of how many
/// reactive resources the class owns.
class DisposalIndex {
  const DisposalIndex._(this._disposals);

  final Map<Element, Set<ReactiveDisposalKind>> _disposals;

  /// Whether some call reachable from `dispose()` disposed [field] using
  /// [kind]'s contract (a bare `field()` call for
  /// [ReactiveDisposalKind.invokeCallback], or `field.dispose()` /
  /// `.close()` / `.cancel()` for the others).
  bool contains(Element field, ReactiveDisposalKind kind) =>
      _disposals[field]?.contains(kind) ?? false;

  static const _methodNameToKind = {
    'dispose': ReactiveDisposalKind.disposeMethod,
    'close': ReactiveDisposalKind.closeMethod,
    'cancel': ReactiveDisposalKind.cancelMethod,
  };

  static DisposalIndex build(
    MethodDeclaration disposeMethod,
    ClassDeclaration classNode,
  ) {
    final disposals = <Element, Set<ReactiveDisposalKind>>{};
    final body = disposeMethod.body;
    if (body is BlockFunctionBody) {
      final visitor = _DisposalIndexVisitor(
        classNode: classNode,
        visitedMethods: {disposeMethod},
        disposals: disposals,
      );
      body.block.accept(visitor);
    }
    return DisposalIndex._(disposals);
  }
}

class _DisposalIndexVisitor extends RecursiveAstVisitor<void> {
  _DisposalIndexVisitor({
    required this.classNode,
    required this.visitedMethods,
    required this.disposals,
  });

  final ClassDeclaration classNode;

  /// Method declarations already walked into (starting with `dispose()`
  /// itself), so a helper that (directly or through another helper) calls
  /// back into an already-visited method can never recurse forever.
  final Set<MethodDeclaration> visitedMethods;
  final Map<Element, Set<ReactiveDisposalKind>> disposals;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.argumentList.arguments.isEmpty) {
      if (node.target == null) {
        // Bare zero-arg call: `field()`, the invokeCallback shape.
        final element = _canonicalElement(node.methodName.element);
        if (element != null) {
          _record(element, ReactiveDisposalKind.invokeCallback);
        }
      } else {
        final kind = DisposalIndex._methodNameToKind[node.methodName.name];
        if (kind != null) {
          final targetElement = _targetElement(node.target);
          if (targetElement != null) _record(targetElement, kind);
        }
      }
    }
    _followLocalHelperCall(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (node.argumentList.arguments.isEmpty) {
      final targetElement = _targetElement(node.function);
      if (targetElement != null) {
        _record(targetElement, ReactiveDisposalKind.invokeCallback);
      }
    }
    super.visitFunctionExpressionInvocation(node);
  }

  void _record(Element element, ReactiveDisposalKind kind) {
    disposals.putIfAbsent(element, () => <ReactiveDisposalKind>{}).add(kind);
  }

  /// If [node] is a zero-argument call to another method declared directly
  /// in the same class (`_disposeResources()`, `this._disposeResources()`),
  /// not yet walked into, also index that method's body — disposal
  /// ownership is sometimes delegated to a small helper rather than
  /// written directly in `dispose()`.
  ///
  /// Deliberately narrow: only a same-class, zero-parameter, `this`/bare
  /// target method resolved by name is followed (no cross-class calls, no
  /// helpers that take arguments).
  void _followLocalHelperCall(MethodInvocation node) {
    if (node.argumentList.arguments.isNotEmpty) return;
    final target = node.target;
    if (target != null && target is! ThisExpression) return;
    final helper = _findZeroArgMethod(classNode, node.methodName.name);
    if (helper == null || !visitedMethods.add(helper)) return;
    final helperBody = helper.body;
    if (helperBody is BlockFunctionBody) {
      helperBody.block.accept(this);
    }
  }
}

MethodDeclaration? _findZeroArgMethod(ClassDeclaration classNode, String name) {
  for (final member in classNode.members) {
    if (member is MethodDeclaration &&
        !member.isStatic &&
        member.name.lexeme == name &&
        (member.parameters?.parameters.isEmpty ?? true)) {
      return member;
    }
  }
  return null;
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

Element? _canonicalElement(Element? element) {
  if (element == null) return null;
  if (element is PropertyAccessorElement) {
    return element.variable?.baseElement ?? element.baseElement;
  }
  return element.baseElement;
}
