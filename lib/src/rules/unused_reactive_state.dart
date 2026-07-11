// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';

/// `unused_reactive_state` (strict, `info`)
///
/// Flags private file-level or field-level reactive state that is created but
/// never referenced in the same resolved Dart unit.
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
    const checker = AllObserverTypeChecker();

    context.registry.addVariableDeclaration((node) {
      if (!_isPrivateFieldOrTopLevel(node)) return;
      final initializer = node.initializer;
      if (initializer == null) return;
      if (!_isReactiveInitializer(initializer, checker)) return;

      final owner = _canonicalElement(node.declaredFragment?.element);
      if (owner == null) return;

      final unit = node.thisOrAncestorOfType<CompilationUnit>();
      if (unit == null) return;
      if (_hasReference(unit: unit, declaration: node, owner: owner)) return;

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

bool _hasReference({
  required CompilationUnit unit,
  required VariableDeclaration declaration,
  required Element owner,
}) {
  final visitor = _ReferenceVisitor(declaration: declaration, owner: owner);
  unit.accept(visitor);
  return visitor.found;
}

class _ReferenceVisitor extends RecursiveAstVisitor<void> {
  _ReferenceVisitor({required this.declaration, required this.owner});

  final VariableDeclaration declaration;
  final Element owner;

  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (found) return;
    if (_isInsideDeclaration(node)) return;

    if (_canonicalElement(node.element) == owner) {
      found = true;
      return;
    }

    super.visitSimpleIdentifier(node);
  }

  bool _isInsideDeclaration(SimpleIdentifier node) =>
      node.offset >= declaration.offset && node.end <= declaration.end;
}

Element? _canonicalElement(Element? element) {
  if (element == null) return null;
  if (element is PropertyAccessorElement) {
    return element.variable?.baseElement ?? element.baseElement;
  }
  return element.baseElement;
}
