// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/all_observer_type_checker.dart';
import '../utils/reactive_disposal_resolver.dart';

/// Quick fix for `dispose_reactive_resources`.
///
/// Inserts the type-correct disposal invocation before `super.dispose()` in
/// the owning class's `dispose()` method. Depending on the resolved type this
/// is `<field>()`, `.dispose()`, `.close()`, or `.cancel()`. This is only
/// offered — and only safe to offer — because the rule already proved that:
///  * the field is declared in the same class as `dispose()`;
///  * `dispose()` exists and has a block body;
///  * the field is not already disposed anywhere in that method.
///
/// The fix never changes program behavior beyond adding the missing call,
/// so it does not require confirmation beyond the standard quick-fix
/// preview every IDE already shows.
class AddDisposeCallFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addVariableDeclaration((node) {
      if (!_containsError(node, analysisError)) return;

      final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classNode == null) return;

      MethodDeclaration? disposeMethod;
      for (final member in classNode.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }
      if (disposeMethod == null) return;

      final body = disposeMethod.body;
      if (body is! BlockFunctionBody) return;

      final fieldName = node.name.lexeme;
      final initializer = node.initializer;
      if (initializer == null) return;
      final disposalResolver = ReactiveDisposalResolver(
        AllObserverTypeChecker(),
      );
      final kind = disposalResolver.resolve(
        node.declaredFragment?.element.type,
        initializer,
      );
      if (kind == null) return;
      final invocation = kind.invocationFor(fieldName);
      final changeBuilder = reporter.createChangeBuilder(
        message: 'Dispose $fieldName in dispose()',
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        final superDispose = _superDisposeStatement(body.block);
        if (superDispose != null) {
          final source = resolver.source.contents.data;
          final lineStart =
              source.lastIndexOf('\n', superDispose.offset - 1) + 1;
          final indent = source.substring(lineStart, superDispose.offset);
          builder.addSimpleInsertion(
            superDispose.offset,
            '$invocation\n$indent',
          );
          return;
        }
        builder.addSimpleInsertion(
          body.block.leftBracket.end,
          '\n    $invocation',
        );
      });
    });
  }

  Statement? _superDisposeStatement(Block block) {
    for (final statement in block.statements) {
      if (statement is! ExpressionStatement) continue;
      final expression = statement.expression;
      if (expression is MethodInvocation &&
          expression.target is SuperExpression &&
          expression.methodName.name == 'dispose' &&
          expression.argumentList.arguments.isEmpty) {
        return statement;
      }
    }
    return null;
  }

  bool _containsError(AstNode node, AnalysisError error) {
    return node.offset <= error.offset &&
        node.offset + node.length >= error.offset + error.length;
  }
}
