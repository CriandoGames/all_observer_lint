// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

/// A single-pass index of every private field / private top-level variable
/// declaration in a [CompilationUnit], and whether each one is referenced
/// anywhere in that unit outside of its own declaration.
///
/// Built once per [CompilationUnit] (see `unused_reactive_state.dart`,
/// which caches the result for the duration of a single rule execution)
/// instead of re-walking the whole unit once per candidate variable, so the
/// number of full-unit traversals stays constant regardless of how many
/// reactive fields the unit declares.
class ReactiveReferenceIndex {
  const ReactiveReferenceIndex._({
    required this.declarations,
    required this.referencedOutsideDeclaration,
  });

  /// Every private field / private top-level [VariableDeclaration] in the
  /// unit, keyed by its canonical declared element.
  final Map<Element, VariableDeclaration> declarations;

  /// The subset of [declarations] keys that are referenced somewhere in the
  /// unit outside of their own declaration's source range.
  final Set<Element> referencedOutsideDeclaration;

  /// Whether [owner] (a key of [declarations]) is used anywhere in the unit
  /// outside of its own declaration.
  bool isReferenced(Element owner) =>
      referencedOutsideDeclaration.contains(owner);

  static ReactiveReferenceIndex build(CompilationUnit unit) {
    final declarations = <Element, VariableDeclaration>{};
    final declarationRanges = <Element, (int, int)>{};

    final declCollector = _CandidateDeclarationCollector();
    unit.accept(declCollector);
    for (final declaration in declCollector.candidates) {
      final element = _canonicalElement(declaration.declaredFragment?.element);
      if (element == null) continue;
      declarations[element] = declaration;
      declarationRanges[element] = (declaration.offset, declaration.end);
    }

    final referenced = <Element>{};
    final refVisitor = _ReferenceCollector(
      declarationRanges: declarationRanges,
      referenced: referenced,
    );
    unit.accept(refVisitor);

    return ReactiveReferenceIndex._(
      declarations: declarations,
      referencedOutsideDeclaration: referenced,
    );
  }
}

bool _isPrivateFieldOrTopLevel(VariableDeclaration node) {
  if (!node.name.lexeme.startsWith('_')) return false;

  final list = node.parent;
  final declaration = list?.parent;
  return declaration is FieldDeclaration ||
      declaration is TopLevelVariableDeclaration;
}

class _CandidateDeclarationCollector extends RecursiveAstVisitor<void> {
  final List<VariableDeclaration> candidates = [];

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (_isPrivateFieldOrTopLevel(node)) candidates.add(node);
    super.visitVariableDeclaration(node);
  }
}

class _ReferenceCollector extends RecursiveAstVisitor<void> {
  _ReferenceCollector({
    required this.declarationRanges,
    required this.referenced,
  });

  final Map<Element, (int, int)> declarationRanges;
  final Set<Element> referenced;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = _canonicalElement(node.element);
    if (element != null) {
      final range = declarationRanges[element];
      final isInsideOwnDeclaration =
          range != null && node.offset >= range.$1 && node.end <= range.$2;
      if (!isInsideOwnDeclaration) referenced.add(element);
    }
    super.visitSimpleIdentifier(node);
  }
}

Element? _canonicalElement(Element? element) {
  if (element == null) return null;
  if (element is PropertyAccessorElement) {
    return element.variable?.baseElement ?? element.baseElement;
  }
  return element.baseElement;
}
