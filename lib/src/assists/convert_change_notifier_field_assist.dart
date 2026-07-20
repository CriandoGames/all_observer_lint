// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../migrations/change_notifier_migration_analyzer.dart';
import '../utils/all_observer_symbol_import_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/semantic_reference_index.dart';
import '../utils/source_edit_plan.dart';

/// `Convert ChangeNotifier field to Observable` assist.
///
/// ```dart
/// class _CounterState extends State<Counter> {
///   int _count = 0;
///   int get count => _count;
///
///   void increment() {
///     _count++;
///     notifyListeners();
///   }
/// }
/// ```
///
/// Triggered on the `_count` declaration, merges the private field and its
/// getter into a single public `Observable<int>` field, rewriting every
/// occurrence of either the field or the getter to `.value` access:
///
/// ```dart
/// class _CounterState extends State<Counter> {
///   final count = Observable(0);
///
///   void increment() {
///     count.value++;
///     notifyListeners();
///   }
/// }
/// ```
///
/// This is deliberately only the first of the project brief's four
/// smaller Etapa F assists (see
/// [ChangeNotifierFieldMigrationAnalyzer] for the full list and rationale):
/// the `notifyListeners()` call above is left completely untouched, even
/// though it is now redundant for this one field — removing it safely
/// requires proving *every* reactive write in that method already notifies
/// through `Observable`, which is a separate, later assist
/// (`documentation/backlog.md`). Likewise `extends ChangeNotifier` is left
/// in place; removing it is also deferred to its own assist.
///
/// All safety evaluation lives in [ChangeNotifierFieldMigrationAnalyzer] —
/// this class only asks whether the field the selection is on allows an
/// assist, then re-derives the getter/class details and assembles the
/// resulting edits.
class ConvertChangeNotifierFieldAssist extends DartAssist {
  static const String _observableSymbolName = 'Observable';

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    SourceRange target,
  ) {
    final checker = AllObserverTypeChecker();
    final analyzer = ChangeNotifierFieldMigrationAnalyzer(checker);
    const importResolver = AllObserverSymbolImportResolver();

    context.registry.addCompilationUnit((unit) {
      final index = UnitSemanticIndex.build(unit, checker);

      VariableDeclaration? field;
      for (final candidate in index.declarations.values) {
        if (candidate.offset <= target.offset &&
            candidate.end >= target.offset + target.length) {
          field = candidate;
          break;
        }
      }
      if (field == null) return;

      final safety = analyzer.evaluate(field, index);
      if (!safety.allowsAssist) return;

      final classNode = field.thisOrAncestorOfType<ClassDeclaration>();
      if (classNode == null) return;

      final privateName = field.name.lexeme;
      final publicName = privateName.substring(1);

      MethodDeclaration? getter;
      for (final member in classNode.members) {
        if (member is MethodDeclaration &&
            member.isGetter &&
            member.name.lexeme == publicName) {
          getter = member;
          break;
        }
      }
      if (getter == null) return;

      final variableList = field.parent;
      if (variableList is! VariableDeclarationList) return;
      final fieldDeclaration = variableList.parent;
      if (fieldDeclaration is! FieldDeclaration) return;

      final initializer = field.initializer;
      if (initializer == null) return;

      final declaredElement = field.declaredFragment?.element;
      if (declaredElement == null) return;
      final fieldElement = _canonicalElementOf(declaredElement);
      final getterElement = _canonicalElementOf(
        getter.declaredFragment?.element,
      );
      if (fieldElement == null || getterElement == null) return;

      final importPlan = importResolver.resolve(
        unit,
        symbolName: _observableSymbolName,
        targetNode: field,
      );
      final observableExpression = importPlan.expression;

      // Only keep an explicit `<Type>` argument when relying on plain
      // inference from the initializer would actually produce a narrower
      // type than the field's own declared type (e.g. `num _score = 0;` —
      // `0` alone infers `int`, which would reject a later `.value = 1.5`).
      // When they already match (or there was no explicit annotation to
      // begin with), the bare inferred form is used, matching the project
      // brief's own example (`final count = Observable(0);`).
      final explicitType = variableList.type;
      var typeArgument = '';
      if (explicitType is NamedType) {
        final initializerType = initializer.staticType;
        final declaredType = declaredElement.type;
        if (initializerType == null || initializerType != declaredType) {
          typeArgument = '<${explicitType.toSource()}>';
        }
      }
      final newDeclaration =
          'final $publicName = $observableExpression$typeArgument'
          '(${initializer.toSource()});';

      final edits = <SourceTextEdit>[
        SourceTextEdit(
          offset: fieldDeclaration.offset,
          length: fieldDeclaration.length,
          replacement: newDeclaration,
        ),
        SourceTextEdit(
          offset: getter.offset,
          length: getter.length,
          replacement: '',
        ),
      ];

      final valueExpression = '$publicName.value';
      for (final occurrence in index.references[fieldElement] ?? const []) {
        final node = occurrence.node;
        if (node is! SimpleIdentifier) continue;
        if (node.offset >= getter.offset && node.end <= getter.end) {
          // Inside the getter body being deleted above — no separate edit
          // needed (and would overlap with the deletion edit).
          continue;
        }
        edits.add(_valueAccessEdit(node, valueExpression));
      }

      final getterOccurrenceCollector = _ElementOccurrenceCollector(
        getterElement,
      );
      unit.accept(getterOccurrenceCollector);
      for (final node in getterOccurrenceCollector.occurrences) {
        edits.add(_valueAccessEdit(node, valueExpression));
      }

      final plan = SourceEditPlan(
        edits: edits,
        importOffset: importPlan.insertionOffset,
        importSource: importPlan.importSource,
      );

      final change = reporter.createChangeBuilder(
        message: 'Convert ChangeNotifier field to Observable',
        priority: 75,
      );
      change.addDartFileEdit((builder) {
        plan.addTo(builder.addSimpleReplacement, builder.addSimpleInsertion);
      });
    });
  }
}

class _ElementOccurrenceCollector extends RecursiveAstVisitor<void> {
  _ElementOccurrenceCollector(this.target);

  final Element target;
  final List<SimpleIdentifier> occurrences = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_canonicalElementOf(node.element) == target) {
      occurrences.add(node);
    }
    super.visitSimpleIdentifier(node);
  }
}

Element? _canonicalElementOf(Element? element) {
  if (element == null) return null;
  if (element is PropertyAccessorElement) {
    return element.variable?.baseElement ?? element.baseElement;
  }
  return element.baseElement;
}

/// Builds the edit that turns a single field/getter occurrence into
/// [replacementExpression] (`<publicName>.value`).
///
/// Dart's bare `$identifier` string-interpolation shorthand only ever
/// captures a single [SimpleIdentifier] — never an extended `identifier.
/// property` chain (`'$score.value'` means `'${score}' '.value'`, the
/// trailing text is literal). Replacing just the identifier's own range
/// there would silently turn `'$score'` into `'$score.value'`, printing a
/// literal `.value` suffix instead of evaluating `.value` as part of the
/// expression. When [node] is exactly the bare expression of such a
/// bracket-less [InterpolationExpression], the whole interpolation node is
/// replaced instead, with explicit braces added
/// (`'${score.value}'`) so the `.value` access is actually evaluated.
SourceTextEdit _valueAccessEdit(
  SimpleIdentifier node,
  String replacementExpression,
) {
  final parent = node.parent;
  if (parent is InterpolationExpression &&
      identical(parent.expression, node) &&
      parent.rightBracket == null) {
    return SourceTextEdit(
      offset: parent.offset,
      length: parent.length,
      replacement: '\${$replacementExpression}',
    );
  }
  return SourceTextEdit(
    offset: node.offset,
    length: node.length,
    replacement: replacementExpression,
  );
}
