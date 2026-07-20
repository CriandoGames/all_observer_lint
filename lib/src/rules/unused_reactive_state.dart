// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/reactive_reference_index.dart';

/// `unused_reactive_state` (strict, `info`)
///
/// Flags private file-level or field-level reactive state that is created but
/// never referenced in the same resolved Dart unit.
///
/// Performance note: the "is this variable referenced elsewhere in the
/// unit" check is backed by a [ReactiveReferenceIndex] built once per
/// [CompilationUnit] (cached for the lifetime of this single rule
/// execution, see `indexes` below) instead of walking the whole unit again
/// for every candidate variable, so a file with N reactive fields performs
/// a constant number of full-unit traversals rather than N of them.
class UnusedReactiveState extends DartLintRule {
  UnusedReactiveState({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'unused_reactive_state';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.unusedReactiveState,
      ),
      errorSeverity: ErrorSeverity.INFO,
    );
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final checker = AllObserverTypeChecker();

    // Local to this single rule execution: never a static/global cache, so
    // it cannot leak analyzer elements or grow across analysis sessions.
    final indexes = Map<CompilationUnit, ReactiveReferenceIndex>.identity();

    context.registry.addVariableDeclaration((node) {
      if (!_isPrivateFieldOrTopLevel(node)) return;
      final initializer = node.initializer;
      if (initializer == null) return;
      if (!_isReactiveInitializer(initializer, checker)) return;

      final owner = _canonicalElement(node.declaredFragment?.element);
      if (owner == null) return;

      final unit = node.thisOrAncestorOfType<CompilationUnit>();
      if (unit == null) return;

      final index = indexes.putIfAbsent(
        unit,
        () => ReactiveReferenceIndex.build(unit),
      );
      if (index.isReferenced(owner)) return;

      reporter.atNode(node, code);
    });
  }
}

bool _isPrivateFieldOrTopLevel(VariableDeclaration node) {
  if (!node.name.lexeme.startsWith('_')) return false;

  final list = node.parent;
  final declaration = list?.parent;
  return declaration is FieldDeclaration ||
      declaration is TopLevelVariableDeclaration;
}

bool _isReactiveInitializer(
  Expression initializer,
  AllObserverTypeChecker checker,
) {
  if (checker.isAnyReactiveResourceCreation(initializer)) return true;
  final type = initializer.staticType;
  return checker.isObservableType(type) ||
      checker.isObservableListType(type) ||
      checker.isComputedType(type);
}

Element? _canonicalElement(Element? element) {
  if (element == null) return null;
  if (element is PropertyAccessorElement) {
    return element.variable?.baseElement ?? element.baseElement;
  }
  return element.baseElement;
}
