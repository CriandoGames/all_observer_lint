import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../fixes/add_dispose_call_fix.dart';
import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';

/// `dispose_reactive_resources`
///
/// Flags fields holding an effect/worker (`effect`, `ever`, `once`,
/// `debounce`, `interval`) or an `ObservableStream` subscription that is
/// never disposed by the owning class's `dispose()` method.
///
/// Scope of this first version, kept intentionally narrow to avoid false
/// positives:
///  * only fields (not local variables) are checked, since only fields have
///    a well-defined owning lifecycle method;
///  * the owning class must declare its own `dispose()` method;
///  * the field's initializer must be a direct
///    `effect(...)`/`ever(...)`/`once(...)`/`debounce(...)`/`interval(...)`
///    call or `ObservableStream(...)` creation — indirection through a
///    helper method is not tracked in this version (see
///    `documentation/backlog.md`);
///  * disposal is recognized as any `<field>.dispose()` call anywhere in
///    the `dispose()` method body.
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

      final disposedFieldNames = _disposedFieldNames(disposeMethod);

      for (final member in classNode.members) {
        if (member is! FieldDeclaration) continue;
        for (final variable in member.fields.variables) {
          final initializer = variable.initializer;
          if (initializer == null) continue;
          if (!_isDisposableReactiveResource(initializer, checker)) continue;
          if (disposedFieldNames.contains(variable.name.lexeme)) continue;

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

  bool _isDisposableReactiveResource(
    Expression initializer,
    AllObserverTypeChecker checker,
  ) {
    if (initializer is MethodInvocation) {
      return checker.isEffectOrWorkerInvocation(initializer);
    }
    if (initializer is InstanceCreationExpression) {
      return checker.isObservableStreamCreation(initializer);
    }
    return false;
  }

  Set<String> _disposedFieldNames(MethodDeclaration disposeMethod) {
    final names = <String>{};
    final body = disposeMethod.body;
    if (body is! BlockFunctionBody) return names;

    for (final statement in body.block.statements) {
      if (statement is! ExpressionStatement) continue;
      final expression = statement.expression;
      if (expression is! MethodInvocation) continue;
      if (expression.methodName.name != disposeMethodName) continue;

      final target = expression.target;
      if (target is SimpleIdentifier) {
        names.add(target.name);
      } else if (target is PropertyAccess && target.target is ThisExpression) {
        names.add(target.propertyName.name);
      }
    }
    return names;
  }

  @override
  List<Fix> getFixes() => [AddDisposeCallFix()];
}
