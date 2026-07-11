import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/all_observer_type_checker.dart';

/// Quick fix for `prefer_batch_for_multiple_related_writes`.
///
/// Wraps the consecutive `.value = ...;` statements reported by the lint in
/// `Observable.batch(() { ... });`, preserving the original statements.
class WrapInObservableBatchFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    const checker = AllObserverTypeChecker();

    context.registry.addBlock((block) {
      final run = _writeRunForError(block, analysisError, checker);
      if (run == null) return;

      final batchExpression = _batchExpression(block);
      if (batchExpression == null) return;

      final source = resolver.source.contents.data;
      final replacement = buildBatchReplacement(
        source: source,
        firstStatement: run.first,
        lastStatement: run.last,
        batchExpression: batchExpression,
      );

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap writes in Observable.batch',
        priority: 70,
      );
      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(run.first.offset, run.last.end - run.first.offset),
          replacement,
        );
      });
    });
  }

  /// Builds the replacement text for the quick fix.
  ///
  /// Kept side-effect-free so tests can validate formatting behavior without
  /// needing to spin up the full analyzer plugin fix pipeline.
  static String buildBatchReplacement({
    required String source,
    required Statement firstStatement,
    required Statement lastStatement,
    required String batchExpression,
  }) {
    final lineStart = source.lastIndexOf('\n', firstStatement.offset - 1) + 1;
    final baseIndent = source.substring(lineStart, firstStatement.offset);
    final statementsSource = source.substring(
      firstStatement.offset,
      lastStatement.end,
    );
    final normalizedLines = statementsSource
        .split('\n')
        .map((line) {
          if (line.startsWith(baseIndent)) {
            return line.substring(baseIndent.length);
          }
          return line;
        })
        .map((line) => '$baseIndent  $line')
        .join('\n');

    return '$batchExpression(() {\n'
        '$normalizedLines\n'
        '$baseIndent});';
  }

  ({Statement first, Statement last})? _writeRunForError(
    Block block,
    AnalysisError error,
    AllObserverTypeChecker checker,
  ) {
    final statements = block.statements;
    var index = 0;
    while (index < statements.length) {
      final runStart = index;
      while (index < statements.length &&
          _isPlainObservableValueWrite(statements[index], checker)) {
        index++;
      }

      final runLength = index - runStart;
      if (runLength >= 3) {
        final first = statements[runStart];
        final last = statements[index - 1];
        if (_containsError(first, error)) {
          return (first: first, last: last);
        }
      }

      if (runLength == 0) index++;
    }
    return null;
  }

  bool _isPlainObservableValueWrite(
    Statement statement,
    AllObserverTypeChecker checker,
  ) {
    if (statement is! ExpressionStatement) return false;
    final expression = statement.expression;
    if (expression is! AssignmentExpression) return false;
    if (expression.operator.lexeme != '=') return false;

    Expression? target;
    String? propertyName;
    if (expression.leftHandSide is PropertyAccess) {
      final access = expression.leftHandSide as PropertyAccess;
      target = access.target;
      propertyName = access.propertyName.name;
    } else if (expression.leftHandSide is PrefixedIdentifier) {
      final access = expression.leftHandSide as PrefixedIdentifier;
      target = access.prefix;
      propertyName = access.identifier.name;
    }
    if (target == null || propertyName != 'value') return false;
    return checker.isObservableType(target.staticType);
  }

  bool _containsError(AstNode node, AnalysisError error) {
    return node.offset <= error.offset &&
        node.offset + node.length >= error.offset + error.length;
  }

  String? _batchExpression(AstNode node) {
    final unit = node.root;
    if (unit is! CompilationUnit) return null;

    for (final directive in unit.directives) {
      if (directive is! ImportDirective) continue;
      if (directive.uri.stringValue !=
          'package:all_observer/all_observer.dart') {
        continue;
      }
      final prefix = directive.prefix?.name;
      if (prefix != null) return '$prefix.Observable.batch';
      return 'Observable.batch';
    }
    return null;
  }
}
