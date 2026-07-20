// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import '../utils/all_observer_type_checker.dart';
import '../utils/migration_safety_result.dart';
import '../utils/semantic_reference_index.dart';

/// How a single occurrence of a candidate `ValueNotifier` field is used,
/// as far as [ValueNotifierMigrationAnalyzer] can prove.
enum _UsageKind {
  /// A `.value` read or write — `Observable` supports the exact same
  /// `.value` getter/setter contract, so this occurrence needs no rewrite
  /// at all.
  valueAccess,

  /// A `.dispose()` call directly on the field — rewritten to `.close()`.
  disposeCall,

  /// An `.addListener(callback)` call directly on the field. See the class
  /// doc, "Why listeners need no rewrite".
  addListenerCall,

  /// An `.removeListener(callback)` call directly on the field. See the
  /// class doc, "Why listeners need no rewrite".
  removeListenerCall,

  /// Anything else: passed as an argument, stored in another variable,
  /// compared, returned, used as a bare `ValueListenable`/`Listenable`,
  /// or reached through some other indirection this analyzer does not
  /// attempt to prove safe.
  unrecognized,
}

/// Evaluates whether a private `ValueNotifier<T>` field is safe to convert
/// to `Observable<T>`, per the project brief's Part 2 ("Conversão de
/// `ValueNotifier`"), implemented as Etapa E.
///
/// ## Why listeners need no rewrite
///
/// The project brief assumes `count.addListener(callback)` may need
/// converting to an `effect`/`ever` worker "só quando a semântica for
/// equivalente". Checking the real, published `all_observer` source
/// (`lib/src/observable/observable.dart`, `lib/src/core/core_observable.dart`)
/// confirms `Observable<T> implements ValueListenable<T>` and its
/// `addListener`/`removeListener` delegate directly to a plain listener
/// registry — exactly like Flutter's own `ValueNotifier`/`ChangeNotifier`:
/// registration never invokes the callback immediately, only future
/// value-change notifications do. Since the semantics are already
/// identical, converting the declaration is enough; leaving
/// `addListener`/`removeListener` calls untouched **is** the correct,
/// fully behavior-preserving choice, not a shortcut — attempting an
/// `effect`/`ever` conversion here would be solving a problem that does
/// not exist for this specific migration (that conversion remains useful
/// on its own terms, as a later, separate modernization step, not a
/// requirement of this one).
///
/// ## Scope (first version)
///
/// - Only a **private** field or top-level declaration is considered (via
///   [UnitSemanticIndex.declarations]) — a local variable is deferred; see
///   `documentation/backlog.md`.
/// - The initializer must be a direct `ValueNotifier(...)`/
///   `ValueNotifier<T>(...)` construction — anything indirect (a factory,
///   a cast, a helper function) is not resolved and stays silent.
/// - Every occurrence of the field outside its own declaration must be
///   one of: a `.value` read/write, a `.dispose()` call, or a single,
///   balanced `addListener`/`removeListener` pair (each called at most
///   once — see [UnitSemanticIndex.listenerRegistrations]/
///   [UnitSemanticIndex.listenerRemovals], which only resolve a simple,
///   directly-`Listenable`-typed, directly-referenced target in the first
///   place). Anything else — passed as an argument (covers
///   `ValueListenableBuilder`-style consumers and any other unknown API in
///   one conservative check), stored in another variable, used as a bare
///   `ValueListenable`/`Listenable`, multiple/unbalanced listener calls —
///   is unrecognized and blocks the whole candidate silently.
class ValueNotifierMigrationAnalyzer {
  const ValueNotifierMigrationAnalyzer(this._checker);

  final AllObserverTypeChecker _checker;

  /// Evaluates [field] (already known to be a private field/top-level
  /// declaration, i.e. a value from [index].declarations) against [index],
  /// built once for the whole compilation unit.
  MigrationSafetyResult evaluate(
    VariableDeclaration field,
    UnitSemanticIndex index,
  ) {
    final declaredElement = field.declaredFragment?.element;
    if (declaredElement == null) {
      return MigrationSafetyResult.silent(['unresolved declared element']);
    }
    if (!_checker.isValueNotifierType(declaredElement.type)) {
      return MigrationSafetyResult.silent([
        'not a ValueNotifier-typed declaration',
      ]);
    }

    final initializer = field.initializer;
    if (initializer is! InstanceCreationExpression ||
        !_checker.isValueNotifierType(initializer.staticType)) {
      return MigrationSafetyResult.silent([
        'initializer is not a direct ValueNotifier(...) construction',
      ]);
    }

    final element = _canonicalElement(declaredElement);
    if (element == null) {
      return MigrationSafetyResult.silent(['unresolved canonical element']);
    }

    final occurrences = index.references[element] ?? const [];
    for (final occurrence in occurrences) {
      final node = occurrence.node;
      if (node is! SimpleIdentifier) {
        return MigrationSafetyResult.silent([
          'occurrence at ${occurrence.node.offset} is not a simple '
              'identifier reference',
        ]);
      }
      if (_classify(node) == _UsageKind.unrecognized) {
        return MigrationSafetyResult.silent([
          'field is used in an unrecognized way at ${node.offset} — could '
              'be a ValueListenable consumer, an argument to an unknown API, '
              'or stored elsewhere',
        ]);
      }
    }

    final addCalls = index.listenerRegistrations[element] ?? const [];
    final removeCalls = index.listenerRemovals[element] ?? const [];
    if (addCalls.length > 1 ||
        removeCalls.length > 1 ||
        addCalls.length != removeCalls.length) {
      return MigrationSafetyResult.silent([
        'addListener/removeListener usage is not a single balanced pair',
      ]);
    }

    return MigrationSafetyResult.safe(MigrationCapability.assist);
  }

  _UsageKind _classify(SimpleIdentifier node) {
    final parent = node.parent;
    if (parent is PrefixedIdentifier && identical(parent.prefix, node)) {
      return parent.identifier.name == 'value'
          ? _UsageKind.valueAccess
          : _UsageKind.unrecognized;
    }
    if (parent is PropertyAccess && identical(parent.target, node)) {
      return parent.propertyName.name == 'value'
          ? _UsageKind.valueAccess
          : _UsageKind.unrecognized;
    }
    if (parent is MethodInvocation && identical(parent.target, node)) {
      final argumentCount = parent.argumentList.arguments.length;
      switch (parent.methodName.name) {
        case 'dispose':
          return argumentCount == 0
              ? _UsageKind.disposeCall
              : _UsageKind.unrecognized;
        case 'addListener':
          return argumentCount == 1
              ? _UsageKind.addListenerCall
              : _UsageKind.unrecognized;
        case 'removeListener':
          return argumentCount == 1
              ? _UsageKind.removeListenerCall
              : _UsageKind.unrecognized;
        default:
          return _UsageKind.unrecognized;
      }
    }
    return _UsageKind.unrecognized;
  }
}

Element? _canonicalElement(Element? element) {
  if (element == null) return null;
  if (element is PropertyAccessorElement) {
    return element.variable?.baseElement ?? element.baseElement;
  }
  return element.baseElement;
}
