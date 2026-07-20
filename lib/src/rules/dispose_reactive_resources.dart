// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../fixes/add_dispose_call_fix.dart';
import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/disposal_index.dart';
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
/// Performance note: whether each field is disposed is answered by a
/// [DisposalIndex] built once per class (see [DisposalIndex.build] in
/// [run]) — the `dispose()` method and its local helpers are walked
/// exactly once per class, not once per candidate resource.
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
    final checker = AllObserverTypeChecker();

    context.registry.addClassDeclaration((classNode) {
      final disposeMethod = _findDisposeMethod(classNode);
      if (disposeMethod == null) return;

      final disposalResolver = ReactiveDisposalResolver(checker);
      final disposalIndex = DisposalIndex.build(disposeMethod, classNode);

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
          if (disposalIndex.contains(field, kind)) continue;

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

  @override
  List<Fix> getFixes() => [AddDisposeCallFix()];
}

Element? _canonicalElement(Element? element) {
  if (element == null) return null;
  if (element is PropertyAccessorElement) {
    return element.variable?.baseElement ?? element.baseElement;
  }
  return element.baseElement;
}
