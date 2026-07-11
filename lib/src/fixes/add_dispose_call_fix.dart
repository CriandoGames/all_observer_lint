import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Quick fix for `dispose_reactive_resources`.
///
/// Inserts `<field>.dispose();` as the first statement of the owning
/// class's `dispose()` method. This is only offered — and only safe to
/// offer — because the rule already proved, statically, that:
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
      final changeBuilder = reporter.createChangeBuilder(
        message: 'Dispose $fieldName in dispose()',
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        final insertOffset = body.block.leftBracket.end;
        builder.addSimpleInsertion(
          insertOffset,
          '\n    $fieldName.dispose();',
        );
      });
    });
  }

  bool _containsError(AstNode node, AnalysisError error) {
    return node.offset <= error.offset &&
        node.offset + node.length >= error.offset + error.length;
  }
}
