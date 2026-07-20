// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../utils/all_observer_type_checker.dart';
import '../utils/disposal_index.dart';
import '../utils/migration_safety_result.dart';
import '../utils/reactive_disposal_resolver.dart';

/// A single field proven safe to move into a `ReactiveScope` by
/// [ReactiveScopeIntroductionAnalyzer], together with everything
/// [IntroduceReactiveScopeAssist] needs to rewrite it without re-deriving
/// this same evidence a second time.
class ReactiveScopeEligibleField {
  const ReactiveScopeEligibleField({
    required this.fieldDeclaration,
    required this.variable,
    required this.kind,
    required this.disposalStatement,
  });

  /// The enclosing `FieldDeclaration` (may declare siblings; only
  /// [variable] itself was proven eligible).
  final FieldDeclaration fieldDeclaration;

  /// The specific `VariableDeclaration` (name + initializer) proven
  /// eligible.
  final VariableDeclaration variable;

  /// How this field is disposed today — always one of the three shapes
  /// `ReactiveScope.run` actually auto-captures (see the class doc):
  /// [ReactiveDisposalKind.closeMethod] for a `Computed`,
  /// [ReactiveDisposalKind.invokeCallback] for an `effect()` `Disposer`, or
  /// [ReactiveDisposalKind.disposeMethod] for a `Worker`.
  final ReactiveDisposalKind kind;

  /// The exact statement inside `dispose()`'s own block that performs the
  /// disposal above — the one edit will delete.
  final ExpressionStatement disposalStatement;
}

/// The result of evaluating a whole class for
/// [IntroduceReactiveScopeAssist]. Deliberately carries more than a bare
/// [MigrationSafetyResult] (unlike every other analyzer in this phase):
/// re-deriving the ordered, exact-statement-level [eligibleFields] list a
/// second time in the assist would mean re-running the same
/// [DisposalIndex] walk and the same direct-block statement scan, with a
/// real risk of the two derivations silently drifting apart. Producing the
/// list once, here, and having the assist consume it directly removes
/// that risk entirely.
class ReactiveScopeIntroductionResult {
  const ReactiveScopeIntroductionResult._({
    required this.safety,
    required this.eligibleFields,
    this.initState,
    this.disposeMethod,
  });

  factory ReactiveScopeIntroductionResult.silent(List<String> reasons) =>
      ReactiveScopeIntroductionResult._(
        safety: MigrationSafetyResult.silent(reasons),
        eligibleFields: const [],
      );

  final MigrationSafetyResult safety;
  final List<ReactiveScopeEligibleField> eligibleFields;
  final MethodDeclaration? initState;
  final MethodDeclaration? disposeMethod;

  bool get allowsAssist => safety.allowsAssist;
}

/// Evaluates whether introducing a `ReactiveScope` is safe for a whole
/// class, per the project brief's Part 10 ("Introdução segura de
/// ReactiveScope"), implemented as Etapa H.
///
/// ## Why this cannot be a small, local edit
///
/// `ReactiveScope.run(fn)` only captures a `Computed`/`effect()`/`Worker`
/// created *while it is executing* — each of those three constructors
/// calls `ReactiveScope.current?.add(...)` internally (confirmed by
/// reading the real, published `all_observer` source: `core_computed.dart`,
/// `effects/effect.dart`, `workers/workers.dart`). A field with an inline
/// initializer (`late final total = Computed(...);`) constructs its value
/// as part of the instance's *construction*, before any `run()` call could
/// possibly be active. Introducing a scope therefore genuinely requires
/// moving the initializer out of the field declaration and into an
/// assignment statement inside a `_scope.run(() { ... })` block — the
/// first migration in this package that relocates code between two
/// different syntactic positions rather than only rewriting in place.
///
/// ## Not every disposable type is scope-eligible
///
/// `ObservableFuture`, `ObservableStream`, `ObservableHistory` and
/// `ObservableSubscription` all share a disposal *method name* with a
/// scope-eligible type (`.close()`/`.dispose()`), but the `ReactiveScope`
/// class doc is explicit that none of them are auto-captured — they must
/// be registered manually via `scope.add(...)`. This analyzer never infers
/// eligibility from [ReactiveDisposalResolver]'s *kind* alone; it always
/// re-checks the field's actual type (`Computed`, or `Worker`, or a
/// `Disposer` whose initializer is proven to be a real `effect(...)`
/// call).
///
/// ## Class-level gates
///
/// - has its own `initState()` with a directly-visible
///   `super.initState();` statement — the insertion point for the moved
///   assignments;
/// - has its own `dispose()` with a directly-visible `super.dispose();`
///   statement — mirrors the exact requirement
///   `ExtractReactiveExpressionToComputedAssist` (Etapa D) already uses,
///   for the same reason: only a persistent, lifecycle-managed object
///   (not a `StatelessWidget`, recreated every rebuild) can safely own a
///   scope;
/// - declares **no explicit constructor** — an explicit constructor body
///   runs *before* `initState()`, so a field it (or another field's
///   inline initializer) reads would now read an unassigned `late` field
///   and throw. Rather than prove no such read exists, this narrows to
///   the case where it structurally cannot happen: no custom constructor
///   at all (the common case for a `State` subclass);
/// - has no existing member named `_scope` (the fixed name this assist
///   always introduces).
///
/// ## Field-level gates (all of the below, per candidate)
///
/// - a private or public, non-static field with a **direct** inline
///   initializer (an `InstanceCreationExpression`/`effect(...)`/worker-
///   function call resolved back to `all_observer` — the same
///   directly-owned check `dispose_reactive_resources` already applies,
///   reused here);
/// - the field's type is scope-auto-captured: `Computed`, `Worker`, or a
///   `Disposer`-typed field whose initializer is a real `effect(...)`
///   call;
/// - already disposed correctly, with the exact matching contract, by a
///   statement **directly** inside `dispose()`'s own block (not through a
///   local helper — [DisposalIndex] would still find a helper-delegated
///   disposal, but this analyzer additionally requires the literal
///   statement to edit be found directly, so a helper-delegated
///   candidate is silently excluded rather than guessed at);
/// - never referenced from another field's initializer anywhere in the
///   class (that initializer would also run during construction, before
///   the moved assignment in `initState()`).
///
/// At least **two** fields must pass every gate above — introducing a
/// scope for a single resource has no consolidation benefit and is not
/// offered.
class ReactiveScopeIntroductionAnalyzer {
  const ReactiveScopeIntroductionAnalyzer(this._checker);

  final AllObserverTypeChecker _checker;

  static const String scopeFieldName = '_scope';

  ReactiveScopeIntroductionResult evaluate(ClassDeclaration classNode) {
    if (classNode.members.any((member) => member is ConstructorDeclaration)) {
      return ReactiveScopeIntroductionResult.silent([
        'class declares an explicit constructor',
      ]);
    }
    if (_hasMemberNamed(classNode, scopeFieldName)) {
      return ReactiveScopeIntroductionResult.silent([
        'a member named $scopeFieldName already exists',
      ]);
    }

    final initState = _findMethod(classNode, 'initState');
    if (initState == null || !_hasDirectSuperCall(initState, 'initState')) {
      return ReactiveScopeIntroductionResult.silent([
        'no initState() with a direct super.initState() call',
      ]);
    }
    final disposeMethod = _findMethod(classNode, 'dispose');
    if (disposeMethod == null ||
        !_hasDirectSuperCall(disposeMethod, 'dispose')) {
      return ReactiveScopeIntroductionResult.silent([
        'no dispose() with a direct super.dispose() call',
      ]);
    }
    final disposeBody = disposeMethod.body;
    if (disposeBody is! BlockFunctionBody) {
      return ReactiveScopeIntroductionResult.silent([
        'dispose() has no block body',
      ]);
    }

    final disposalResolver = ReactiveDisposalResolver(_checker);
    final disposalIndex = DisposalIndex.build(disposeMethod, classNode);

    // Every candidate scope-eligible field element, collected first, so
    // the cross-referencing gate below ("never read from a sibling
    // field's initializer") can check the *whole* candidate set instead
    // of only fields already confirmed on earlier iterations.
    final candidates = <Element, VariableDeclaration>{};
    final candidateFieldDeclarations = <Element, FieldDeclaration>{};
    for (final member in classNode.members) {
      if (member is! FieldDeclaration || member.isStatic) continue;
      // A `FieldDeclaration` sharing one `VariableDeclarationList` across
      // several variables (`final a = ..., b = ...;`) would need partial
      // edits inside that shared list rather than a whole-declaration
      // replacement. Rather than handle that, this narrows to the
      // overwhelmingly common one-variable-per-declaration shape.
      if (member.fields.variables.length != 1) continue;
      for (final variable in member.fields.variables) {
        final initializer = variable.initializer;
        if (initializer == null) continue;
        final declaredElement = variable.declaredFragment?.element;
        if (declaredElement == null) continue;
        if (!_isScopeAutoCapturedType(declaredElement.type, initializer)) {
          continue;
        }
        if (!_isDirectlyOwnedResource(initializer)) continue;
        final element = _canonicalElement(declaredElement);
        if (element == null) continue;
        candidates[element] = variable;
        candidateFieldDeclarations[element] = member;
      }
    }

    if (candidates.length < 2) {
      return ReactiveScopeIntroductionResult.silent([
        'fewer than 2 scope-eligible resource fields',
      ]);
    }

    final eligible = <ReactiveScopeEligibleField>[];
    for (final entry in candidates.entries) {
      final element = entry.key;
      final variable = entry.value;
      final declaredElement = variable.declaredFragment?.element;
      final kind = disposalResolver.resolve(
        declaredElement?.type,
        variable.initializer,
      );
      if (kind == null) continue;
      if (!disposalIndex.contains(element, kind)) continue;

      final disposalStatement = _findDirectDisposalStatement(
        disposeBody.block,
        element,
        kind,
      );
      if (disposalStatement == null) continue;

      if (_isReferencedByAnotherFieldInitializer(
        classNode,
        element,
        variable,
      )) {
        continue;
      }

      eligible.add(
        ReactiveScopeEligibleField(
          fieldDeclaration: candidateFieldDeclarations[element]!,
          variable: variable,
          kind: kind,
          disposalStatement: disposalStatement,
        ),
      );
    }

    if (eligible.length < 2) {
      return ReactiveScopeIntroductionResult.silent([
        'fewer than 2 fields proven safe to move (disposed directly in '
            'dispose(), never read from a sibling field initializer)',
      ]);
    }

    // Preserve declaration order, matching the relative order the moved
    // initializers already ran in as inline field initializers.
    eligible.sort((a, b) => a.variable.offset.compareTo(b.variable.offset));

    return ReactiveScopeIntroductionResult._(
      safety: MigrationSafetyResult.safe(MigrationCapability.assist),
      eligibleFields: eligible,
      initState: initState,
      disposeMethod: disposeMethod,
    );
  }

  bool _isScopeAutoCapturedType(DartType? type, Expression initializer) {
    if (_checker.isComputedType(type)) return true;
    if (_checker.isWorkerType(type)) return true;
    if (_checker.isDisposerType(type) &&
        initializer is MethodInvocation &&
        _checker.isEffectInvocation(initializer)) {
      return true;
    }
    return false;
  }

  /// Mirrors `DisposeReactiveResources._isDirectlyOwnedResource` — a
  /// resource resolved straight from a call/constructor known to belong
  /// to `all_observer`, never through a helper/factory this analyzer
  /// cannot see into.
  bool _isDirectlyOwnedResource(Expression initializer) {
    if (initializer is MethodInvocation) {
      if (_checker.isEffectOrWorkerInvocation(initializer)) return true;
      return _checker.isAllObserverElement(initializer.methodName.element);
    }
    if (initializer is InstanceCreationExpression) {
      return _checker.isAllObserverElement(initializer.constructorName.element);
    }
    return false;
  }

  ExpressionStatement? _findDirectDisposalStatement(
    Block disposeBlock,
    Element fieldElement,
    ReactiveDisposalKind kind,
  ) {
    for (final statement in disposeBlock.statements) {
      if (statement is! ExpressionStatement) continue;
      final expression = statement.expression;

      if (kind == ReactiveDisposalKind.invokeCallback) {
        if (_isDirectInvokeCallbackOf(expression, fieldElement)) {
          return statement;
        }
        continue;
      }

      if (expression is! MethodInvocation) continue;
      if (expression.argumentList.arguments.isNotEmpty) continue;
      if (expression.methodName.name != kind.memberName) continue;
      final target = expression.target;
      if (target == null) continue;
      final targetElement = _targetElement(target);
      if (targetElement == fieldElement) return statement;
    }
    return null;
  }

  /// Whether [expression] is a bare, zero-argument `field()` call invoking
  /// [fieldElement] — the `invokeCallback` disposal shape.
  ///
  /// Depending on whether the callee resolves to an actual method or to a
  /// field/local variable of a callable type, the analyzer represents this
  /// exact syntax (`identifier();`) as either a [MethodInvocation] (the
  /// parser always uses this shape for bare-identifier call syntax,
  /// regardless of what the identifier resolves to) or, once resolution
  /// determines the callee is a callable *value* rather than a method, as
  /// a [FunctionExpressionInvocation] (an implicit `.call()`). A
  /// `late final Disposer disposeEffect = effect(...);` field invoked as
  /// `disposeEffect();` resolves to the latter — this mirrors the exact
  /// dual handling [DisposalIndex] already relies on for the identical
  /// shape (see `lib/src/utils/disposal_index.dart`,
  /// `visitFunctionExpressionInvocation`).
  bool _isDirectInvokeCallbackOf(Expression expression, Element fieldElement) {
    if (expression is MethodInvocation) {
      if (expression.argumentList.arguments.isNotEmpty) return false;
      if (expression.target != null) return false;
      final element = _canonicalElement(expression.methodName.element);
      return element == fieldElement;
    }
    if (expression is FunctionExpressionInvocation) {
      if (expression.argumentList.arguments.isNotEmpty) return false;
      final targetElement = _targetElement(expression.function);
      return targetElement == fieldElement;
    }
    return false;
  }

  /// Whether [fieldElement] is read *immediately* (outside any nested
  /// closure) inside another field's initializer in [classNode].
  ///
  /// That sibling initializer runs during construction, before the
  /// assignment this migration moves into `initState()`, so an immediate
  /// read there would newly throw a `LateInitializationError` after the
  /// rewrite. A reference *inside* a nested closure is different and
  /// deliberately not flagged: `Computed`, `effect`, and the worker
  /// factories all take their reactive logic as a callback — precisely so
  /// it runs lazily, on demand, never synchronously as part of
  /// constructing the wrapper object itself. `late final doubled =
  /// Computed(() => total.value * 2);` never reads `total.value` at
  /// construction time, only whenever `doubled.value` is later evaluated
  /// — by which point construction (and now `initState()`) has already
  /// finished, `total` included. [_ImmediateElementReferenceFinder] models
  /// exactly this by refusing to descend into any `FunctionExpression`.
  bool _isReferencedByAnotherFieldInitializer(
    ClassDeclaration classNode,
    Element fieldElement,
    VariableDeclaration ownVariable,
  ) {
    for (final member in classNode.members) {
      if (member is! FieldDeclaration) continue;
      for (final variable in member.fields.variables) {
        if (identical(variable, ownVariable)) continue;
        final initializer = variable.initializer;
        if (initializer == null) continue;
        final finder = _ImmediateElementReferenceFinder(fieldElement);
        initializer.accept(finder);
        if (finder.found) return true;
      }
    }
    return false;
  }

  bool _hasMemberNamed(ClassDeclaration classNode, String name) {
    for (final member in classNode.members) {
      if (member is FieldDeclaration) {
        if (member.fields.variables.any(
          (variable) => variable.name.lexeme == name,
        )) {
          return true;
        }
      }
      if (member is MethodDeclaration && member.name.lexeme == name) {
        return true;
      }
    }
    return false;
  }

  MethodDeclaration? _findMethod(ClassDeclaration classNode, String name) {
    for (final member in classNode.members) {
      if (member is MethodDeclaration &&
          member.name.lexeme == name &&
          !member.isStatic) {
        return member;
      }
    }
    return null;
  }

  bool _hasDirectSuperCall(MethodDeclaration method, String name) {
    final body = method.body;
    if (body is! BlockFunctionBody) return false;
    for (final statement in body.block.statements) {
      if (statement is ExpressionStatement) {
        final expression = statement.expression;
        if (expression is MethodInvocation &&
            expression.target is SuperExpression &&
            expression.methodName.name == name &&
            expression.argumentList.arguments.isEmpty) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Finds a reference to [target] within an expression, *without*
/// descending into any nested closure — see
/// [ReactiveScopeIntroductionAnalyzer._isReferencedByAnotherFieldInitializer]
/// for why a reference inside a closure is not a hazard here.
class _ImmediateElementReferenceFinder extends RecursiveAstVisitor<void> {
  _ImmediateElementReferenceFinder(this.target);

  final Element target;
  bool found = false;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Deliberately not calling super: a closure's body runs only when
    // later invoked, never synchronously as part of evaluating the
    // enclosing initializer expression.
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_canonicalElement(node.element) == target) found = true;
    super.visitSimpleIdentifier(node);
  }
}

Element? _targetElement(Expression? expression) {
  if (expression is SimpleIdentifier) {
    return _canonicalElement(expression.element);
  }
  if (expression is PropertyAccess && expression.target is ThisExpression) {
    return _canonicalElement(expression.propertyName.element);
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
