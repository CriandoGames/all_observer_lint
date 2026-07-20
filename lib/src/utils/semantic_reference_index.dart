// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import 'all_observer_type_checker.dart';
import 'reactive_collection_operation_classifier.dart';

/// A single occurrence of a declared [Element] somewhere in the indexed
/// [CompilationUnit], outside of its own declaration.
class ElementOccurrence {
  const ElementOccurrence(this.node, this.element);

  /// The smallest AST node representing this occurrence (an identifier, a
  /// property access, ...).
  final AstNode node;

  /// The canonical (see `baseElement`/property-accessor-unwrapped) element
  /// this occurrence resolves to.
  final Element element;
}

/// A single-pass-per-capability semantic index of one resolved
/// [CompilationUnit], shared across the migration analyzers introduced for
/// the assisted-migrations phase (`lib/src/migrations/*`,
/// `lib/src/rules/*`) so a file with many candidate classes/fields/
/// listeners is walked a small, constant number of times overall — never
/// once per candidate.
///
/// [declarations] and [references] are cheap and always needed (every
/// existing rule that asks "is this element referenced elsewhere" already
/// pays this cost — see `ReactiveReferenceIndex`, which this generalizes
/// by keeping full occurrence nodes instead of only a referenced/not-
/// referenced boolean) so they are computed eagerly in [build].
/// [reactiveReads], [reactiveMutations], [listenerRegistrations] and
/// [listenerRemovals] are each a `late final` field computed lazily, on
/// first access only: a rule that never asks about listeners never pays
/// for a listener-call walk of the unit (see the project brief's Part 11/
/// 12, "não construir tudo sempre" / fast paths).
///
/// Scope note: [reactiveReads]/[reactiveMutations] record *that* an
/// occurrence reads/mutates a reactive value somewhere in the unit — they
/// deliberately do not classify *where* (inside a tracking scope or not).
/// That context-sensitive judgment stays in each rule, which can consult
/// the small, bounded occurrence list here and then walk up from each
/// occurrence node locally (cost bounded by AST depth, not file size) —
/// the same division of labor `ReactiveReadCollector`/
/// `RebuildScopeFinder` already use for tracking-scope-specific analysis.
class UnitSemanticIndex {
  UnitSemanticIndex._(
    this._unit,
    this._checker,
    this.declarations,
    this._declarationRanges,
  );

  final CompilationUnit _unit;
  final AllObserverTypeChecker _checker;

  /// Every private field / private top-level [VariableDeclaration] in the
  /// unit, keyed by its canonical declared element. Mirrors
  /// `ReactiveReferenceIndex.declarations`.
  final Map<Element, VariableDeclaration> declarations;

  final Map<Element, (int, int)> _declarationRanges;

  /// Every occurrence of each key of [declarations] anywhere in the unit,
  /// outside of its own declaration range. Superset of
  /// `ReactiveReferenceIndex.referencedOutsideDeclaration`: migrations need
  /// the actual occurrence nodes to reason about read/write/listener
  /// shape, not just presence of a reference.
  late final Map<Element, List<ElementOccurrence>> references =
      _buildReferences();

  /// Reactive `.value` reads and reactive-collection reads found anywhere
  /// in the unit, keyed by the element being read (the `Observable`/
  /// `Computed`/`ObservableList`/`ObservableMap`/`ObservableSet` itself,
  /// not the `.value`/method call node).
  late final Map<Element, List<AstNode>> reactiveReads =
      _buildReactiveOccurrences().reads;

  /// Reactive `.value` writes and reactive-collection mutations
  /// (including [ReactiveCollectionOperationKind.replacement], both
  /// counted as mutations here — callers that need the distinction should
  /// re-classify the recorded node with
  /// [ReactiveCollectionOperationClassifier] directly) found anywhere in
  /// the unit, keyed by the mutated element.
  late final Map<Element, List<AstNode>> reactiveMutations =
      _buildReactiveOccurrences().mutations;

  /// `target.addListener(callback)` invocations anywhere in the unit,
  /// keyed by the resolved `target` element. Only recognizes a receiver
  /// resolved as `Listenable`-shaped (`AllObserverTypeChecker.
  /// isFlutterListenableType`, which also covers `all_observer`'s
  /// `Observable`/`Computed` — both implement `ValueListenable`) with a
  /// simple (`identifier`/`this.field`) target — anything more indirect is
  /// left out of the index (stays invisible to migrations that consult
  /// it), matching "permanecer silencioso em caso de dúvida".
  late final Map<Element, List<MethodInvocation>> listenerRegistrations =
      _buildListenerCalls('addListener');

  /// `target.removeListener(callback)` invocations anywhere in the unit,
  /// same resolution rules as [listenerRegistrations].
  late final Map<Element, List<MethodInvocation>> listenerRemovals =
      _buildListenerCalls('removeListener');

  /// Whether [owner] (a key of [declarations]) is used anywhere in the
  /// unit outside of its own declaration.
  bool isReferencedOutsideDeclaration(Element owner) =>
      references[owner]?.isNotEmpty ?? false;

  static UnitSemanticIndex build(
    CompilationUnit unit,
    AllObserverTypeChecker checker,
  ) {
    final declarations = <Element, VariableDeclaration>{};
    final ranges = <Element, (int, int)>{};

    final collector = _DeclarationCollector();
    unit.accept(collector);
    for (final declaration in collector.candidates) {
      final element = _canonicalElement(declaration.declaredFragment?.element);
      if (element == null) continue;
      declarations[element] = declaration;
      ranges[element] = (declaration.offset, declaration.end);
    }

    return UnitSemanticIndex._(unit, checker, declarations, ranges);
  }

  Map<Element, List<ElementOccurrence>> _buildReferences() {
    final result = <Element, List<ElementOccurrence>>{};
    final visitor = _ReferenceCollector(
      declarationRanges: _declarationRanges,
      onOccurrence: (node, element) {
        result
            .putIfAbsent(element, () => [])
            .add(ElementOccurrence(node, element));
      },
    );
    _unit.accept(visitor);
    return result;
  }

  ({Map<Element, List<AstNode>> reads, Map<Element, List<AstNode>> mutations})
  _buildReactiveOccurrences() {
    final reads = <Element, List<AstNode>>{};
    final mutations = <Element, List<AstNode>>{};
    final classifier = ReactiveCollectionOperationClassifier(_checker);
    final visitor = _ReactiveOccurrenceCollector(
      checker: _checker,
      classifier: classifier,
      onRead: (node, element) => reads.putIfAbsent(element, () => []).add(node),
      onMutation: (node, element) =>
          mutations.putIfAbsent(element, () => []).add(node),
    );
    _unit.accept(visitor);
    return (reads: reads, mutations: mutations);
  }

  Map<Element, List<MethodInvocation>> _buildListenerCalls(String methodName) {
    final result = <Element, List<MethodInvocation>>{};
    final visitor = _ListenerCallCollector(
      checker: _checker,
      methodName: methodName,
      onCall: (node, element) =>
          result.putIfAbsent(element, () => []).add(node),
    );
    _unit.accept(visitor);
    return result;
  }
}

bool _isPrivateFieldOrTopLevel(VariableDeclaration node) {
  if (!node.name.lexeme.startsWith('_')) return false;
  final list = node.parent;
  final declaration = list?.parent;
  return declaration is FieldDeclaration ||
      declaration is TopLevelVariableDeclaration;
}

class _DeclarationCollector extends RecursiveAstVisitor<void> {
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
    required this.onOccurrence,
  });

  final Map<Element, (int, int)> declarationRanges;
  final void Function(AstNode node, Element element) onOccurrence;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = _canonicalElement(node.element);
    if (element != null && declarationRanges.containsKey(element)) {
      final range = declarationRanges[element]!;
      final isInsideOwnDeclaration =
          node.offset >= range.$1 && node.end <= range.$2;
      if (!isInsideOwnDeclaration) onOccurrence(node, element);
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Whole-unit reactive read/mutation occurrence collector. Deliberately
/// coarser-grained than `ReactiveReadCollector`/`ReactiveWriteDetector`: it
/// never treats a nested closure as a tracking-scope boundary (there is no
/// single tracking scope here — this walks the *entire* unit), it only
/// answers "does an occurrence of this element's `.value`/collection
/// operation exist anywhere, and is it a read or a write".
class _ReactiveOccurrenceCollector extends RecursiveAstVisitor<void> {
  _ReactiveOccurrenceCollector({
    required this.checker,
    required this.classifier,
    required this.onRead,
    required this.onMutation,
  });

  final AllObserverTypeChecker checker;
  final ReactiveCollectionOperationClassifier classifier;
  final void Function(AstNode node, Element element) onRead;
  final void Function(AstNode node, Element element) onMutation;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _recordValueAccess(node, node.target, node.propertyName.name);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _recordValueAccess(node, node.prefix, node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }

  void _recordValueAccess(
    Expression node,
    Expression? target,
    String propertyName,
  ) {
    if (target == null || propertyName != 'value') return;
    final targetType = target.staticType;
    if (!checker.isObservableType(targetType) &&
        !checker.isComputedType(targetType)) {
      return;
    }
    final targetElement = _targetElement(target);
    if (targetElement == null) return;
    if (_isWriteTarget(node)) {
      onMutation(node, targetElement);
    } else {
      onRead(node, targetElement);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target != null) {
      final kind = classifier.classifyMethodInvocation(node);
      final targetElement = _targetElement(target);
      if (targetElement != null) {
        switch (kind) {
          case ReactiveCollectionOperationKind.read:
            onRead(node, targetElement);
          case ReactiveCollectionOperationKind.mutation:
          case ReactiveCollectionOperationKind.replacement:
            onMutation(node, targetElement);
          case ReactiveCollectionOperationKind.unknown:
            break;
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    final target = node.target;
    if (target != null) {
      final kind = classifier.classifyIndexExpression(node);
      final targetElement = _targetElement(target);
      if (targetElement != null) {
        switch (kind) {
          case ReactiveCollectionOperationKind.read:
            onRead(node, targetElement);
          case ReactiveCollectionOperationKind.mutation:
          case ReactiveCollectionOperationKind.replacement:
            onMutation(node, targetElement);
          case ReactiveCollectionOperationKind.unknown:
            break;
        }
      }
    }
    super.visitIndexExpression(node);
  }

  bool _isWriteTarget(Expression expression) {
    final parent = expression.parent;
    if (parent is AssignmentExpression &&
        identical(parent.leftHandSide, expression)) {
      return true;
    }
    if (parent is PrefixExpression && identical(parent.operand, expression)) {
      return parent.operator.lexeme == '++' || parent.operator.lexeme == '--';
    }
    if (parent is PostfixExpression && identical(parent.operand, expression)) {
      return parent.operator.lexeme == '++' || parent.operator.lexeme == '--';
    }
    return false;
  }
}

class _ListenerCallCollector extends RecursiveAstVisitor<void> {
  _ListenerCallCollector({
    required this.checker,
    required this.methodName,
    required this.onCall,
  });

  final AllObserverTypeChecker checker;
  final String methodName;
  final void Function(MethodInvocation node, Element element) onCall;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == methodName &&
        node.argumentList.arguments.length == 1) {
      final target = node.target;
      if (target != null &&
          checker.isFlutterListenableType(target.staticType)) {
        final element = _targetElement(target);
        if (element != null) onCall(node, element);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Resolves the canonical element behind a simple `target` expression: a
/// bare identifier (`count.addListener(...)`) or a `this.field` access
/// (`this.count.addListener(...)`). Anything more indirect (a method call,
/// an index expression, a cascade) is intentionally not resolved — the
/// caller then simply does not index that occurrence, per "permanecer
/// silencioso em caso de dúvida".
Element? _targetElement(Expression? expression) {
  if (expression is SimpleIdentifier) {
    return _canonicalElement(expression.element);
  }
  if (expression is PropertyAccess && expression.target is ThisExpression) {
    return _canonicalElement(expression.propertyName.element);
  }
  if (expression is PrefixedIdentifier) {
    return _canonicalElement(expression.identifier.element);
  }
  return null;
}

/// Unwraps a getter/setter accessor to the field/variable element it
/// belongs to, and normalizes to the element's `baseElement` — the same
/// canonicalization already used by `ReactiveReferenceIndex`/
/// `DisposalIndex`, duplicated here rather than shared across files to
/// match this package's existing per-file convention (see
/// `documentation/backlog.md`).
Element? _canonicalElement(Element? element) {
  if (element == null) return null;
  if (element is PropertyAccessorElement) {
    return element.variable?.baseElement ?? element.baseElement;
  }
  return element.baseElement;
}
