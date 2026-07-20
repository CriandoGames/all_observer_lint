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
import '../utils/tracking_callback_resolver.dart';

/// `copied_reactive_collection_outside_tracking` (strict, `info`,
/// experimental)
///
/// Flags a local variable that copies an `ObservableList`/`ObservableMap`/
/// `ObservableSet` into a plain snapshot (`.toList()`/`.toSet()`) *before*
/// an `Observer`/`Computed`/`effect` tracking scope, when that snapshot —
/// not the original reactive collection — is what gets read inside the
/// tracking scope:
///
/// ```dart
/// final visibleItems = items.toList();
/// return Observer(
///   () => ListView(children: visibleItems.map(buildItem).toList()),
/// );
/// ```
///
/// `visibleItems` is a plain `List`, copied before the `Observer` builder
/// ever ran. The `Observer` reads `visibleItems`, not `items` — it tracks
/// nothing, and never rebuilds when `items` changes.
///
/// Deliberately narrow, per the project's false-positive policy:
///
/// - only a **local** `final`/`var` variable declaration is considered — a
///   field snapshot is out of scope for this rule's first version, since
///   proving "read inside this tracking scope, in this method" for a field
///   would need whole-class flow analysis this rule does not attempt;
/// - only a `.toList()`/`.toSet()` snapshot is recognized today — a spread
///   collection-literal snapshot (`[...items]`, `{...map}`) is tracked as
///   future work, see `documentation/backlog.md`;
/// - the snapshot's own static type must not itself be a reactive
///   collection (so `final same = items;`, which keeps tracking, is never
///   flagged);
/// - the snapshot variable must never be reassigned anywhere in the unit —
///   a variable refreshed before every use is not a stale snapshot, and
///   this rule cannot prove *where* in control flow a reassignment
///   happens relative to each tracking-scope read, so it stays silent
///   whenever one exists anywhere;
/// - the original collection must be a statically resolvable simple
///   reference (`items`, `this.items`, `widget.items`) — an original
///   reached only through a more complex expression is not resolved, and
///   this rule stays silent rather than guess;
/// - the original collection's declaring element must be confirmed **not**
///   read inside the same tracking callback — when the original is also
///   read there, the `Observer`/`Computed`/`effect` already tracks it
///   correctly through that read, so flagging would risk a false positive
///   from an unprovable "the snapshot is the only thing being tracked"
///   claim.
///
/// This rule only emits a diagnostic — no assist/quick fix ships yet (see
/// the project brief's "Separar diagnóstico de transformação"): moving the
/// snapshot expression into the tracking scope, or extracting it to a
/// `Computed`, both require additional safety proof (single use, purity,
/// safe insertion point) not yet implemented.
///
/// See
/// `documentation/en/rules/copied_reactive_collection_outside_tracking.md`.
class CopiedReactiveCollectionOutsideTracking extends DartLintRule {
  CopiedReactiveCollectionOutsideTracking({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'copied_reactive_collection_outside_tracking';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(
        DiagnosticMessageKey.copiedReactiveCollectionOutsideTracking,
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
    final trackingResolver = TrackingCallbackResolver(checker);

    context.registry.addVariableDeclarationStatement((statement) {
      for (final variable in statement.variables.variables) {
        _checkVariable(
          variable: variable,
          statement: statement,
          checker: checker,
          trackingResolver: trackingResolver,
          reporter: reporter,
          code: code,
        );
      }
    });
  }

  void _checkVariable({
    required VariableDeclaration variable,
    required VariableDeclarationStatement statement,
    required AllObserverTypeChecker checker,
    required TrackingCallbackResolver trackingResolver,
    required ErrorReporter reporter,
    required LintCode code,
  }) {
    final initializer = variable.initializer;
    if (initializer == null) return;

    final declaredElement = variable.declaredFragment?.element;
    final snapshotElement = _canonicalElement(declaredElement);
    if (snapshotElement == null) return;

    // The variable's own static type must not itself be a reactive
    // collection — otherwise no copy actually happened (e.g. `final same
    // = items;`, which keeps tracking `items` directly).
    final variableType = declaredElement?.type;
    if (checker.isObservableListType(variableType) ||
        checker.isObservableMapType(variableType) ||
        checker.isObservableSetType(variableType)) {
      return;
    }

    final source = _snapshotSource(initializer, checker);
    if (source == null) return;

    final originalElement = _originalCollectionElement(source);
    if (originalElement == null) return;

    final unit = statement.thisOrAncestorOfType<CompilationUnit>();
    final body = statement.thisOrAncestorOfType<FunctionBody>();
    if (unit == null || body == null) return;

    if (_isReassignedAnywhere(unit, snapshotElement)) return;

    final closures = _TrackingClosureCollector(trackingResolver);
    body.accept(closures);

    for (final closure in closures.found) {
      if (closure.offset <= statement.offset) continue;
      final reads = _ReadElementsCollector();
      closure.accept(reads);
      if (!reads.elements.contains(snapshotElement)) continue;
      if (reads.elements.contains(originalElement)) continue;
      reporter.atNode(variable, code);
      return;
    }
  }

  /// Returns the reactive-collection expression a `.toList()`/`.toSet()`
  /// [initializer] is ultimately derived from, or `null` if [initializer]
  /// is not that shape at all.
  Expression? _snapshotSource(
    Expression initializer,
    AllObserverTypeChecker checker,
  ) {
    if (initializer is! MethodInvocation) return null;
    if (initializer.methodName.name != 'toList' &&
        initializer.methodName.name != 'toSet') {
      return null;
    }
    return _findReactiveCollectionInChain(initializer.target, checker);
  }

  /// Walks down a method-call/property-access chain (`items.where(...).
  /// toList()`, `map.keys.toList()`) looking for the first expression whose
  /// static type is a known reactive collection.
  ///
  /// `map.keys`/`counters.values`/`counters.entries` — a bare `target.
  /// property` where both sides are simple names — parses as
  /// [PrefixedIdentifier], not [PropertyAccess] (the latter is only used
  /// when the target itself is a more complex expression); both must be
  /// walked the same way, mirroring `_originalCollectionElement`'s existing
  /// dual handling of the same two node shapes.
  Expression? _findReactiveCollectionInChain(
    Expression? expression,
    AllObserverTypeChecker checker,
  ) {
    if (expression == null) return null;
    final type = expression.staticType;
    if (checker.isObservableListType(type) ||
        checker.isObservableMapType(type) ||
        checker.isObservableSetType(type)) {
      return expression;
    }
    if (expression is MethodInvocation) {
      return _findReactiveCollectionInChain(expression.target, checker);
    }
    if (expression is PropertyAccess) {
      return _findReactiveCollectionInChain(expression.target, checker);
    }
    if (expression is PrefixedIdentifier) {
      return _findReactiveCollectionInChain(expression.prefix, checker);
    }
    return null;
  }

  Element? _originalCollectionElement(Expression source) {
    if (source is SimpleIdentifier) {
      return _canonicalElement(source.element);
    }
    if (source is PropertyAccess) {
      return _canonicalElement(source.propertyName.element);
    }
    if (source is PrefixedIdentifier) {
      return _canonicalElement(source.identifier.element);
    }
    return null;
  }

  bool _isReassignedAnywhere(CompilationUnit unit, Element element) {
    final collector = _ReassignmentCollector(element);
    unit.accept(collector);
    return collector.found;
  }
}

class _ReassignmentCollector extends RecursiveAstVisitor<void> {
  _ReassignmentCollector(this.element);

  final Element element;
  bool found = false;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final lhs = node.leftHandSide;
    if (lhs is SimpleIdentifier && _canonicalElement(lhs.element) == element) {
      found = true;
    }
    super.visitAssignmentExpression(node);
  }
}

/// Finds every `Observer`/`Computed`/`effect` builder closure in a subtree,
/// via the same semantic resolution [TrackingCallbackResolver] already
/// centralizes for every other rule that needs it.
class _TrackingClosureCollector extends RecursiveAstVisitor<void> {
  _TrackingClosureCollector(this.resolver);

  final TrackingCallbackResolver resolver;
  final List<FunctionExpression> found = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final observerBuilder = resolver.observerBuilder(node);
    if (observerBuilder != null) found.add(observerBuilder);
    final computedBuilder = resolver.computedBuilder(node);
    if (computedBuilder != null) found.add(computedBuilder);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final effectBuilder = resolver.effectBuilder(node);
    if (effectBuilder != null) found.add(effectBuilder);
    super.visitMethodInvocation(node);
  }
}

/// Collects the canonical element behind every identifier reference in a
/// subtree (bare identifiers, `this.field`'s property name, and
/// `prefix.identifier`'s member name are all visited generically by
/// [visitSimpleIdentifier] already, since both `PropertyAccess` and
/// `PrefixedIdentifier` have a `SimpleIdentifier` child for the accessed
/// member). Used here only for set-membership checks (“is this element
/// referenced anywhere in this closure”), so false extra entries from
/// unrelated identifiers are harmless.
class _ReadElementsCollector extends RecursiveAstVisitor<void> {
  final Set<Element> elements = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = _canonicalElement(node.element);
    if (element != null) elements.add(element);
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
