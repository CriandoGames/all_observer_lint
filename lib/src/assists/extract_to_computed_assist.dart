// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/all_observer_symbol_import_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/source_edit_plan.dart';

/// `Extract reactive expression to Computed` assist.
///
/// ```dart
/// Observer(
///   () => Text('${price.value * quantity.value}'),
/// )
/// ```
///
/// Triggered on `price.value * quantity.value`, extracts it to a field and
/// replaces the expression with a `.value` read of that field:
///
/// ```dart
/// late final total = Computed(() => price.value * quantity.value);
///
/// Observer(
///   () => Text('${total.value}'),
/// )
/// ```
///
/// (the field is actually inserted as `computedValue` — see "Naming" below
/// for why this first version does not attempt `total`.)
///
/// ## Scope (first version)
///
/// This is deliberately the narrowest safe slice of Part 9 of the project
/// brief, per "permanecer silencioso em caso de dúvida". The assist is only
/// offered when **every** one of the following holds; when any of them
/// don't, it stays unavailable rather than guess.
///
/// **Trigger.** The candidate expression must read two or more *distinct*
/// reactive values (`.value` of an `Observable`/`Computed`) — the smallest
/// such expression containing the selection is chosen, exactly like
/// `WrapSmallestReactiveSubtreeAssist` chooses the smallest Widget. A
/// single repeated read of the *same* value (`count.value + count.value`)
/// does not count as two distinct reads and is not offered.
/// [Deferred: the brief's alternate trigger — the same expression appearing
/// more than once — is not implemented in this version; see
/// `documentation/backlog.md`.]
///
/// **Purity.** The candidate expression must contain none of: an
/// assignment; an increment/decrement (`++`/`--`); an `await`; a nested
/// closure (`FunctionExpression`); a reactive-resource creation
/// (`Observable`/`Computed`/the reactive collections/`ObservableFuture`/
/// `ObservableStream`/`ReactiveScope`, or a `.obs` access); or **any method
/// call at all**. That last restriction is intentionally the most
/// conservative possible reading of "no impure call" — general call purity
/// is undecidable from syntax alone, and this package's policy is to stay
/// silent rather than risk offering a transformation that changes behavior.
/// See `documentation/backlog.md` for the plan to loosen this with a
/// curated allow-list of known-pure `dart:core` methods.
///
/// **Locality.** Every identifier referenced by the candidate expression
/// (reactive or not) must resolve to an instance field or a top-level
/// declaration — never a local variable or a parameter of the enclosing
/// method. A field-level `late final` cannot close over a method's locals,
/// so if it does, the assist stays unavailable rather than generate
/// invalid code. This also blocks any reference to `BuildContext` (whose
/// only source is a method parameter anyway) and to `widget` (a `State`
/// subclass's accessor for its associated `StatefulWidget`) — the latter
/// specifically because supporting it correctly requires initializing the
/// new field from `initState()` instead of as a field initializer (the
/// brief's own example shows this split), which this first version does
/// not implement; see `documentation/backlog.md`.
///
/// **Owner lifecycle.** The enclosing class must declare its own
/// `dispose()` method with a directly-visible `super.dispose();` call (the
/// same shape `dispose_reactive_resources`/`AddDisposeCallFix` already
/// require and insert before). This is not just about *finding somewhere*
/// to add `close()` — it is required for correctness: only a `State`
/// object persists unchanged across rebuilds, so only there is a `late
/// final` field guaranteed to be created once. A `StatelessWidget` instance
/// is recreated on every rebuild, so a field on it would silently
/// reproduce the exact "recreated every rebuild" bug class
/// `avoid_reactive_creation_in_build` exists to catch elsewhere in this
/// package. Classes without this exact `dispose()` shape are left alone.
/// [Deferred: skipping the individual `close()` call when the field is
/// created inside an existing `ReactiveScope.run()` — Etapa H's own
/// migration — is not implemented yet; this version always adds it.]
///
/// ## Naming
///
/// The brief asks for a derived name (`total`, `fullName`, ...) "somente
/// quando houver confiança". This package has no reliable way to derive
/// meaning from an arbitrary expression shape, so this first version always
/// falls back to the brief's own documented fallback:
/// `computedValue`/`computedValue2`/... (picking the first name not already
/// declared in the class). Smarter, evidence-based naming is tracked in
/// `documentation/backlog.md` rather than guessed here.
///
/// ## Insertion point
///
/// The new field is always inserted as the first member of the class body
/// — a single, deterministic, always-valid position, regardless of which
/// method the original expression lives in (`late` defers evaluation to
/// first access, so declaration order relative to other fields does not
/// matter).
class ExtractReactiveExpressionToComputedAssist extends DartAssist {
  static const String _fallbackNameBase = 'computedValue';
  static const String _computedSymbolName = 'Computed';

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    SourceRange target,
  ) {
    final checker = AllObserverTypeChecker();
    const importResolver = AllObserverSymbolImportResolver();

    context.registry.addCompilationUnit((unit) {
      final candidate = _findExtractionCandidate(unit, target, checker);
      if (candidate == null) return;

      final classNode = candidate.thisOrAncestorOfType<ClassDeclaration>();
      if (classNode == null) return;

      final disposeMethod = _findDisposeMethod(classNode);
      if (disposeMethod == null) return;
      final disposeBody = disposeMethod.body;
      if (disposeBody is! BlockFunctionBody) return;
      final superDispose = _superDisposeStatement(disposeBody.block);
      if (superDispose == null) return;

      final source = resolver.source.contents.data;
      final exprSource = source.substring(candidate.offset, candidate.end);
      final fieldName = _pickName(_existingMemberNames(classNode));

      final importPlan = importResolver.resolve(
        unit,
        symbolName: _computedSymbolName,
        targetNode: classNode,
      );

      final insertOffset = classNode.leftBracket.end;
      final disposeLineStart =
          source.lastIndexOf('\n', superDispose.offset - 1) + 1;
      final disposeIndent = source.substring(
        disposeLineStart,
        superDispose.offset,
      );

      final plan = SourceEditPlan(
        edits: [
          SourceTextEdit(
            offset: candidate.offset,
            length: candidate.length,
            replacement: '$fieldName.value',
          ),
          SourceTextEdit(
            offset: insertOffset,
            length: 0,
            replacement:
                '\n  late final $fieldName = '
                '${importPlan.expression}(() => $exprSource);\n',
          ),
          SourceTextEdit(
            offset: superDispose.offset,
            length: 0,
            replacement: '$fieldName.close();\n$disposeIndent',
          ),
        ],
        importOffset: importPlan.insertionOffset,
        importSource: importPlan.importSource,
      );

      final change = reporter.createChangeBuilder(
        message: 'Extract reactive expression to Computed',
        priority: 75,
      );
      change.addDartFileEdit((builder) {
        plan.addTo(builder.addSimpleReplacement, builder.addSimpleInsertion);
      });
    });
  }

  Expression? _findExtractionCandidate(
    CompilationUnit unit,
    SourceRange target,
    AllObserverTypeChecker checker,
  ) {
    final finder = _CandidateFinder(target, checker);
    unit.accept(finder);
    return finder.best;
  }

  MethodDeclaration? _findDisposeMethod(ClassDeclaration classNode) {
    for (final member in classNode.members) {
      if (member is MethodDeclaration &&
          member.name.lexeme == 'dispose' &&
          !member.isStatic) {
        return member;
      }
    }
    return null;
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

  Set<String> _existingMemberNames(ClassDeclaration classNode) {
    final names = <String>{};
    for (final member in classNode.members) {
      if (member is FieldDeclaration) {
        for (final variable in member.fields.variables) {
          names.add(variable.name.lexeme);
        }
      } else if (member is MethodDeclaration) {
        names.add(member.name.lexeme);
      }
    }
    return names;
  }

  String _pickName(Set<String> existing) {
    if (!existing.contains(_fallbackNameBase)) return _fallbackNameBase;
    var suffix = 2;
    while (existing.contains('$_fallbackNameBase$suffix')) {
      suffix++;
    }
    return '$_fallbackNameBase$suffix';
  }
}

/// Finds the smallest [Expression] containing [target] that qualifies as
/// an extraction candidate — see the assist's class doc, "Trigger" /
/// "Purity" / "Locality".
///
/// Uses [GeneralizingAstVisitor.visitExpression] to examine *every*
/// expression in the unit generically (rather than one visit method per
/// concrete expression type), since a qualifying candidate can be any
/// shape (`BinaryExpression`, `StringInterpolation`, ...) — unlike
/// `WrapSmallestReactiveSubtreeAssist`'s search, which only ever looks for
/// a specific `.value` access shape.
class _CandidateFinder extends GeneralizingAstVisitor<void> {
  _CandidateFinder(this.target, this.checker);

  final SourceRange target;
  final AllObserverTypeChecker checker;
  Expression? best;

  bool _contains(AstNode node) {
    final selectionEnd = target.offset + target.length;
    return node.offset <= target.offset && node.end >= selectionEnd;
  }

  @override
  void visitExpression(Expression node) {
    if (_contains(node) && _qualifies(node)) {
      final current = best;
      if (current == null || node.length < current.length) {
        best = node;
      }
    }
    super.visitExpression(node);
  }

  bool _qualifies(Expression node) {
    final reads = _ReactiveReadElementCollector(checker);
    node.accept(reads);
    if (reads.elements.length < 2) return false;

    final purity = _ImpurityCollector(checker);
    node.accept(purity);
    return !purity.blocked;
  }
}

/// Collects the canonical element behind every distinct `.value` read of an
/// `Observable`/`Computed` in a subtree — used to count how many *distinct*
/// reactive values a candidate expression depends on.
class _ReactiveReadElementCollector extends RecursiveAstVisitor<void> {
  _ReactiveReadElementCollector(this.checker);

  final AllObserverTypeChecker checker;
  final Set<Element> elements = {};

  void _check(Expression? valueTarget, String propertyName) {
    if (valueTarget == null || propertyName != 'value') return;
    final type = valueTarget.staticType;
    if (!checker.isObservableType(type) && !checker.isComputedType(type)) {
      return;
    }
    final element = _elementOf(valueTarget);
    if (element != null) elements.add(element);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _check(node.target, node.propertyName.name);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _check(node.prefix, node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }
}

/// Collects whether a candidate expression contains any construct that
/// disqualifies it from extraction — see the assist's class doc, "Purity"
/// / "Locality". A single pass sets [blocked] as soon as any disqualifying
/// construct is found; the visitor keeps running (rather than short-
/// circuiting) since [RecursiveAstVisitor] has no built-in early exit, but
/// this is cheap for the small expressions this assist targets.
class _ImpurityCollector extends RecursiveAstVisitor<void> {
  _ImpurityCollector(this.checker);

  final AllObserverTypeChecker checker;
  bool blocked = false;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    blocked = true;
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if (node.operator.lexeme == '++' || node.operator.lexeme == '--') {
      blocked = true;
    }
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (node.operator.lexeme == '++' || node.operator.lexeme == '--') {
      blocked = true;
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    blocked = true;
    super.visitAwaitExpression(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    blocked = true;
    super.visitFunctionExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Deliberately the most conservative reading of "no impure call" — see
    // the assist's class doc, "Purity".
    blocked = true;
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.staticType;
    if (checker.isReactiveValueType(type) ||
        checker.isObservableFutureType(type) ||
        checker.isObservableStreamType(type) ||
        checker.isReactiveScopeType(type)) {
      blocked = true;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (checker.isObsExtensionAccess(node)) blocked = true;
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (checker.isObsExtensionAccess(node)) blocked = true;
    // Deliberately no BuildContext check here: `node.staticType` on a
    // `PrefixedIdentifier` is the *accessed member's* type (e.g. `bool` for
    // `context.mounted`), not the prefix's — checking it here would look at
    // the wrong node entirely. `visitSimpleIdentifier` below already checks
    // the prefix itself (`context`), which is where a BuildContext-typed
    // value actually appears, via the same recursive visit into children
    // every other node in this class relies on.
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // A named-argument label (`x` in `Point(x: x.value)`) is not a
    // reference to anything in the current scope — it resolves to the
    // *callee's* formal parameter, which would otherwise be misread by
    // `_isNonFieldDependency` as if it were a local/parameter of the
    // enclosing method. Skip it entirely; the actual argument expression
    // (`x.value`) is visited separately and still fully checked.
    if (node.parent is Label) return;
    if (_isBuildContextTyped(node.staticType)) blocked = true;
    if (_isWidgetAccessor(node)) blocked = true;
    if (_isNonFieldDependency(node)) blocked = true;
    super.visitSimpleIdentifier(node);
  }

  bool _isBuildContextTyped(DartType? type) {
    final element = type?.element;
    return element?.name == 'BuildContext' &&
        checker.isFlutterFrameworkElement(element);
  }

  /// `widget` — a `State` subclass's accessor for its associated
  /// `StatefulWidget` — is declared by Flutter's own `State` class, so its
  /// resolved element's declaring library is `package:flutter/`. See the
  /// assist's class doc, "Locality", for why this is blocked in this first
  /// version rather than supported via an `initState()`-based insertion.
  bool _isWidgetAccessor(SimpleIdentifier node) {
    if (node.name != 'widget') return false;
    final element = node.element;
    return element != null && checker.isFlutterFrameworkElement(element);
  }

  /// Every identifier must resolve to an instance field or a top-level
  /// declaration — never a local variable or a parameter of the enclosing
  /// method (a field-level `late final` cannot close over either). Getter/
  /// setter/method names reached through member access (e.g. `value` in
  /// `count.value`) resolve to accessor/method elements, never to
  /// [LocalVariableElement]/[FormalParameterElement], so they are
  /// unaffected by this check.
  bool _isNonFieldDependency(SimpleIdentifier node) {
    final element = node.element;
    return element is LocalVariableElement || element is FormalParameterElement;
  }
}

Element? _elementOf(Expression expression) {
  if (expression is SimpleIdentifier) {
    return _canonicalElement(expression.element);
  }
  if (expression is PropertyAccess) {
    return _canonicalElement(expression.propertyName.element);
  }
  if (expression is PrefixedIdentifier) {
    return _canonicalElement(expression.identifier.element);
  }
  return null;
}

Element? _canonicalElement(Element? element) {
  if (element == null) return null;
  if (element is PropertyAccessorElement) {
    return element.variable?.baseElement ?? element.baseElement;
  }
  return element.baseElement;
}
