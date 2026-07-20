// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../migrations/value_notifier_migration_analyzer.dart';
import '../utils/all_observer_symbol_import_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/semantic_reference_index.dart';
import '../utils/source_edit_plan.dart';

/// `Convert ValueNotifier to Observable` assist.
///
/// ```dart
/// final ValueNotifier<int> _count = ValueNotifier(0);
///
/// void increment() => _count.value++;
///
/// @override
/// void dispose() {
///   _count.dispose();
///   super.dispose();
/// }
/// ```
///
/// Triggered on the `_count` declaration, converts just the type/
/// constructor names:
///
/// ```dart
/// final Observable<int> _count = Observable(0);
///
/// void increment() => _count.value++;
///
/// @override
/// void dispose() {
///   _count.close();
///   super.dispose();
/// }
/// ```
///
/// `.value` reads/writes are left completely untouched — `Observable`'s
/// `.value` getter/setter is a drop-in match for `ValueNotifier`'s. Any
/// `addListener`/`removeListener` call already present is *also* left
/// untouched (see [ValueNotifierMigrationAnalyzer], "Why listeners need no
/// rewrite" — `Observable.addListener`/`removeListener` are verified,
/// real-source-confirmed drop-in equivalents, never invoking the callback
/// immediately). Only the type annotation (if explicit), the constructor
/// call, and any `.dispose()` call are rewritten.
///
/// All safety evaluation lives in [ValueNotifierMigrationAnalyzer] — this
/// class only asks whether the field the selection is on allows an assist,
/// then assembles the resulting edits. See that class's doc for the full
/// list of gates (private-only, direct construction, recognized-usage-only,
/// balanced listeners).
class ConvertValueNotifierAssist extends DartAssist {
  static const String _observableSymbolName = 'Observable';

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    SourceRange target,
  ) {
    final checker = AllObserverTypeChecker();
    final analyzer = ValueNotifierMigrationAnalyzer(checker);
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

      final initializer = field.initializer;
      if (initializer is! InstanceCreationExpression) return;
      final constructorType = initializer.constructorName.type;

      final variableList = field.parent;
      final explicitType = variableList is VariableDeclarationList
          ? variableList.type
          : null;

      final declaredElement = field.declaredFragment?.element;
      final element = declaredElement == null
          ? null
          : _canonicalElementOf(declaredElement);
      if (element == null) return;

      final edits = <SourceTextEdit>[
        SourceTextEdit(
          offset: constructorType.name.offset,
          length: constructorType.name.length,
          replacement: _observableSymbolName,
        ),
      ];
      if (explicitType is NamedType) {
        edits.add(
          SourceTextEdit(
            offset: explicitType.name.offset,
            length: explicitType.name.length,
            replacement: _observableSymbolName,
          ),
        );
      }

      for (final occurrence in index.references[element] ?? const []) {
        final node = occurrence.node;
        if (node is! SimpleIdentifier) continue;
        final parent = node.parent;
        if (parent is MethodInvocation &&
            identical(parent.target, node) &&
            parent.methodName.name == 'dispose' &&
            parent.argumentList.arguments.isEmpty) {
          edits.add(
            SourceTextEdit(
              offset: parent.methodName.offset,
              length: parent.methodName.length,
              replacement: 'close',
            ),
          );
        }
      }

      final importPlan = importResolver.resolve(
        unit,
        symbolName: _observableSymbolName,
        targetNode: field,
      );

      final plan = SourceEditPlan(
        edits: edits,
        importOffset: importPlan.insertionOffset,
        importSource: importPlan.importSource,
      );

      final change = reporter.createChangeBuilder(
        message: 'Convert ValueNotifier to Observable',
        priority: 75,
      );
      change.addDartFileEdit((builder) {
        plan.addTo(builder.addSimpleReplacement, builder.addSimpleInsertion);
      });
    });
  }
}

Element? _canonicalElementOf(Element element) {
  if (element is PropertyAccessorElement) {
    return element.variable?.baseElement ?? element.baseElement;
  }
  return element.baseElement;
}
