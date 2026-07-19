// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../fixes/add_dispose_call_fix.dart';
import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/reactive_disposal_resolver.dart';

/// `dispose_reactive_resources`
///
/// Flags directly owned fields whose resolved all_observer disposal contract
/// is not fulfilled by the owning class's `dispose()` method.
///
/// Scope of this first version, kept intentionally narrow to avoid false
/// positives:
///  * only fields (not local variables) are checked, since only fields have
///    a well-defined owning lifecycle method;
///  * the owning class must declare its own `dispose()` method;
///  * the field's initializer must be a direct, semantically resolved owned
///    resource creation; helper/factory ownership is not inferred;
///  * the required callback/`dispose`/`close`/`cancel` call is selected from
///    the field's resolved static type and matched back to the field element.
///
/// See `documentation/en/rules/dispose_reactive_resources.md`.
class DisposeReactiveResources extends DartLintRule {
  DisposeReactiveResources({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'dispose_reactive_resources';
  static const String disposeMethodName = 'dispose';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.reactiveResourceNotDisposed,
      ),
      errorSeverity: ErrorSeverity.WARNING,
    );
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    const checker = AllObserverTypeChecker();

    context.registry.addClassDeclaration((classNode) {
      final disposeMethod = _findDisposeMethod(classNode);
      if (disposeMethod == null) return;

      const disposalResolver = ReactiveDisposalResolver(checker);

      for (final member in classNode.members) {
        if (member is! FieldDeclaration) continue;
        for (final variable in member.fields.variables) {
          final initializer = variable.initializer;
          if (initializer == null) continue;
          final field = _canonicalElement(variable.declaredFragment?.element);
          if (field == null) continue;
          final kind = disposalResolver.resolve(
            variable.declaredFragment?.element.type,
            initializer,
          );
          if (kind == null) continue;
          if (!_isDirectlyOwnedResource(initializer, checker, kind)) continue;
          if (_isDisposed(disposeMethod, field, kind, classNode)) continue;

          reporter.atNode(variable, code);
        }
      }
    });
  }

  MethodDeclaration? _findDisposeMethod(ClassDeclaration classNode) {
    for (final member in classNode.members) {
      if (member is MethodDeclaration &&
          member.name.lexeme == disposeMethodName &&
          !member.isStatic) {
        return member;
      }
    }
    return null;
  }

  bool _isDirectlyOwnedResource(
    Expression initializer,
    AllObserverTypeChecker checker,
    ReactiveDisposalKind kind,
  ) {
    if (initializer is MethodInvocation) {
      if (checker.isEffectOrWorkerInvocation(initializer)) return true;
      return checker.isAllObserverElement(initializer.methodName.element) &&
          kind != ReactiveDisposalKind.invokeCallback;
    }
    if (initializer is InstanceCreationExpression) {
      return checker.isAllObserverElement(initializer.constructorName.element);
    }
    return false;
  }

  bool _isDisposed(
    MethodDeclaration disposeMethod,
    Element field,
    ReactiveDisposalKind kind,
    ClassDeclaration classNode,
  ) {
    final body = disposeMethod.body;
    if (body is! BlockFunctionBody) return false;
    final visitor = _DisposalCallVisitor(field, kind, classNode, {
      disposeMethod,
    });
    body.block.accept(visitor);
    return visitor.found;
  }

  @override
  List<Fix> getFixes() => [AddDisposeCallFix()];
}

class _DisposalCallVisitor extends RecursiveAstVisitor<void> {
  _DisposalCallVisitor(this.field, this.kind, this.classNode, this.visited);

  final Element field;
  final ReactiveDisposalKind kind;
  final ClassDeclaration classNode;

  /// Method declarations already walked into (starting with `dispose()`
  /// itself), so a helper that (directly or through another helper) calls
  /// back into an already-visited method can never recurse forever.
  final Set<MethodDeclaration> visited;
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (found) return;
    if (kind == ReactiveDisposalKind.invokeCallback) {
      if (node.target == null &&
          node.argumentList.arguments.isEmpty &&
          _canonicalElement(node.methodName.element) == field) {
        found = true;
        return;
      }
    } else if (node.methodName.name == kind.memberName &&
        node.argumentList.arguments.isEmpty &&
        _targetElement(node.target) == field) {
      found = true;
      return;
    }
    _followLocalHelperCall(node);
    if (found) return;
    super.visitMethodInvocation(node);
  }

  /// If [node] is a zero-argument call to another method declared directly
  /// in the same class (`_disposeResources()`, `this._disposeResources()`),
  /// not yet walked into, also search that method's body for the required
  /// disposal call — disposal ownership is sometimes delegated to a small
  /// helper rather than written directly in `dispose()`.
  ///
  /// Deliberately narrow: only a same-class, zero-parameter, `this`/bare
  /// target method resolved by name is followed (no cross-class calls, no
  /// helpers that take arguments), keeping this a strict widening of what
  /// counts as "disposed" rather than a new source of false negatives.
  void _followLocalHelperCall(MethodInvocation node) {
    if (node.argumentList.arguments.isNotEmpty) return;
    final target = node.target;
    if (target != null && target is! ThisExpression) return;
    final helper = _findZeroArgMethod(classNode, node.methodName.name);
    if (helper == null || !visited.add(helper)) return;
    final helperBody = helper.body;
    if (helperBody is BlockFunctionBody) {
      helperBody.block.accept(this);
    }
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (found) return;
    if (kind == ReactiveDisposalKind.invokeCallback &&
        node.argumentList.arguments.isEmpty &&
        _targetElement(node.function) == field) {
      found = true;
      return;
    }
    super.visitFunctionExpressionInvocation(node);
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
