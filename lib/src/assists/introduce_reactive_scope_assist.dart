// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../migrations/reactive_scope_introduction_analyzer.dart';
import '../utils/all_observer_symbol_import_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/source_edit_plan.dart';

/// `Introduce ReactiveScope` assist.
///
/// ```dart
/// class _DashboardState extends State<Dashboard> {
///   late final Computed<int> total = Computed(() => a.value + b.value);
///   late final Disposer disposeEffect = effect(() => print(total.value));
///
///   @override
///   void initState() {
///     super.initState();
///   }
///
///   @override
///   void dispose() {
///     total.close();
///     disposeEffect();
///     super.dispose();
///   }
/// }
/// ```
///
/// Triggered anywhere inside the class, introduces a `ReactiveScope` that
/// captures both resources' disposal automatically:
///
/// ```dart
/// class _DashboardState extends State<Dashboard> {
///   late final ReactiveScope _scope = ReactiveScope();
///   late final Computed<int> total;
///   late final Disposer disposeEffect;
///
///   @override
///   void initState() {
///     super.initState();
///     _scope.run(() {
///       total = Computed(() => a.value + b.value);
///       disposeEffect = effect(() => print(total.value));
///     });
///   }
///
///   @override
///   void dispose() {
///     _scope.dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// All safety evaluation — which fields qualify, that they are already
/// disposed correctly and directly inside `dispose()`, that none is read
/// from a sibling field's initializer — lives in
/// [ReactiveScopeIntroductionAnalyzer]; this class only consumes its
/// [ReactiveScopeIntroductionResult] and assembles the edits. See that
/// class's doc for the full gate list and why this is the first migration
/// in the package that relocates code between two different syntactic
/// positions (a field initializer and a method body) rather than only
/// rewriting in place.
class IntroduceReactiveScopeAssist extends DartAssist {
  static const String _reactiveScopeSymbolName = 'ReactiveScope';

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    SourceRange target,
  ) {
    final checker = AllObserverTypeChecker();
    final analyzer = ReactiveScopeIntroductionAnalyzer(checker);
    const importResolver = AllObserverSymbolImportResolver();

    context.registry.addCompilationUnit((unit) {
      ClassDeclaration? classNode;
      for (final declaration in unit.declarations) {
        if (declaration is ClassDeclaration &&
            declaration.offset <= target.offset &&
            declaration.end >= target.offset + target.length) {
          classNode = declaration;
          break;
        }
      }
      if (classNode == null) return;

      final result = analyzer.evaluate(classNode);
      if (!result.allowsAssist) return;
      final initState = result.initState;
      final disposeMethod = result.disposeMethod;
      if (initState == null || disposeMethod == null) return;

      final initStateBody = initState.body;
      if (initStateBody is! BlockFunctionBody) return;
      final superInitState = _directSuperCallStatement(
        initStateBody.block,
        'initState',
      );
      if (superInitState == null) return;

      final disposeBody = disposeMethod.body;
      if (disposeBody is! BlockFunctionBody) return;
      final superDispose = _directSuperCallStatement(
        disposeBody.block,
        'dispose',
      );
      if (superDispose == null) return;

      final source = resolver.source.contents.data;

      final importPlan = importResolver.resolve(
        unit,
        symbolName: _reactiveScopeSymbolName,
        targetNode: classNode,
      );
      final scopeExpression = importPlan.expression;

      final edits = <SourceTextEdit>[];

      // 1. `late final ReactiveScope _scope = ReactiveScope();` as the
      //    first member of the class body — same deterministic insertion
      //    point `ExtractReactiveExpressionToComputedAssist` (Etapa D)
      //    already uses.
      edits.add(
        SourceTextEdit(
          offset: classNode.leftBracket.end,
          length: 0,
          replacement:
              '\n  late final $scopeExpression _scope = '
              '$scopeExpression();\n',
        ),
      );

      // 2. Each eligible field's declaration loses its inline initializer
      //    (moved to (3) below) and gains `late` (required: a `final`
      //    field with no initializer must be `late`).
      for (final eligible in result.eligibleFields) {
        final variable = eligible.variable;
        final typeText = _typeTextFor(variable);
        if (typeText == null) return; // stay silent; should not happen
        edits.add(
          SourceTextEdit(
            offset: eligible.fieldDeclaration.offset,
            length: eligible.fieldDeclaration.length,
            replacement: 'late final $typeText ${variable.name.lexeme};',
          ),
        );
      }

      // 3. `initState()`: right after `super.initState();`, assign every
      //    eligible field inside one `_scope.run(() { ... });` call, in
      //    the same relative order they ran in as inline initializers.
      final initStateIndent = _leadingIndentOf(source, superInitState.offset);
      final assignments = result.eligibleFields
          .map(
            (eligible) =>
                '$initStateIndent  ${eligible.variable.name.lexeme} = '
                '${eligible.variable.initializer!.toSource()};',
          )
          .join('\n');
      edits.add(
        SourceTextEdit(
          offset: superInitState.offset,
          length: 0,
          replacement:
              '_scope.run(() {\n$assignments\n$initStateIndent});\n'
              '$initStateIndent',
        ),
      );

      // 4. `dispose()`: every eligible field's own disposal statement is
      //    removed; a single `_scope.dispose();` replaces them all, right
      //    before `super.dispose();`.
      for (final eligible in result.eligibleFields) {
        edits.add(
          SourceTextEdit(
            offset: eligible.disposalStatement.offset,
            length: eligible.disposalStatement.length,
            replacement: '',
          ),
        );
      }
      final disposeIndent = _leadingIndentOf(source, superDispose.offset);
      edits.add(
        SourceTextEdit(
          offset: superDispose.offset,
          length: 0,
          replacement: '_scope.dispose();\n$disposeIndent',
        ),
      );

      final plan = SourceEditPlan(
        edits: _mergeSameOffsetEdits(edits),
        importOffset: importPlan.insertionOffset,
        importSource: importPlan.importSource,
      );

      final change = reporter.createChangeBuilder(
        message: 'Introduce ReactiveScope',
        priority: 74,
      );
      change.addDartFileEdit((builder) {
        plan.addTo(builder.addSimpleReplacement, builder.addSimpleInsertion);
      });
    });
  }

  String? _typeTextFor(VariableDeclaration variable) {
    final variableList = variable.parent;
    final explicitType = variableList is VariableDeclarationList
        ? variableList.type
        : null;
    if (explicitType is NamedType) return explicitType.toSource();
    final declaredType = variable.declaredFragment?.element.type;
    return declaredType?.getDisplayString();
  }

  String _leadingIndentOf(String source, int statementOffset) {
    final lineStart = source.lastIndexOf('\n', statementOffset - 1) + 1;
    return source.substring(lineStart, statementOffset);
  }

  Statement? _directSuperCallStatement(Block block, String methodName) {
    for (final statement in block.statements) {
      if (statement is ExpressionStatement) {
        final expression = statement.expression;
        if (expression is MethodInvocation &&
            expression.target is SuperExpression &&
            expression.methodName.name == methodName &&
            expression.argumentList.arguments.isEmpty) {
          return statement;
        }
      }
    }
    return null;
  }

  /// Guards against two edits landing at the exact same offset — e.g. the
  /// new `_scope` field's zero-length insertion at
  /// `classNode.leftBracket.end` and an eligible field's own declaration
  /// replacement, when that field happens to be the very first member
  /// with no intervening whitespace. [SourceEditPlan]'s overlap check
  /// would otherwise depend on `List.sort`'s (unspecified) tie-breaking
  /// for equal offsets to decide whether that pair throws. Merging here —
  /// the zero-length insertion's text first, then the other edit's own
  /// replacement — removes the ambiguity entirely rather than relying on
  /// sort stability.
  List<SourceTextEdit> _mergeSameOffsetEdits(List<SourceTextEdit> edits) {
    final byOffset = <int, SourceTextEdit>{};
    final order = <int>[];
    for (final edit in edits) {
      final existing = byOffset[edit.offset];
      if (existing == null) {
        byOffset[edit.offset] = edit;
        order.add(edit.offset);
        continue;
      }
      final zeroLength = existing.length == 0 ? existing : edit;
      final nonZero = existing.length == 0 ? edit : existing;
      byOffset[edit.offset] = SourceTextEdit(
        offset: nonZero.offset,
        length: nonZero.length,
        replacement: zeroLength.replacement + nonZero.replacement,
      );
    }
    return [for (final offset in order) byOffset[offset]!];
  }
}
