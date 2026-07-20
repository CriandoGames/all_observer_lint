// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Centralized semantic identification of `all_observer` symbols.
///
/// This is the single place in the package that knows how to recognize
/// `Observable`, `Computed`, `Observer`, `.obs`, `watch`, `effect`, workers
/// (`ever`/`once`/`debounce`/`interval`), `batch`, `ObservableFuture` and
/// `ObservableStream`. Rules must never compare identifier text on their own
/// (e.g. `name == 'Observable'`); they must go through this checker so a
/// class named `Observable` from an unrelated package is never flagged
/// (see requirement #9/#10 in the project brief).
///
/// ## How matching works
///
/// Every check first resolves the relevant [Element] and confirms its
/// declaring library URI starts with [allObserverPackageUriPrefix] *before*
/// looking at the simple name. Unresolved elements (partially-typed or
/// broken code) are treated as "unknown" and never match, which keeps the
/// rules conservative per the project's false-positive policy.
///
/// ## Compatibility note
///
/// The exact sub-library each symbol lives in (`all_observer.dart` vs.
/// `src/...`) is intentionally not encoded here beyond the package prefix,
/// so internal reorganizations of `all_observer` do not require changes to
/// this file. If a future `all_observer` release renames a core symbol,
/// only [_coreClassNames] / [_workerFunctionNames] / friends below need to
/// change — no rule file should ever need editing for that.
class AllObserverTypeChecker {
  AllObserverTypeChecker();

  /// Per-execution memoization of the supertype/interface/mixin hierarchy
  /// walk, keyed by [InterfaceElement] identity (never by [DartType], since
  /// distinct [InterfaceType] instances can share the same declaring
  /// element, e.g. different generic instantiations of the same class).
  ///
  /// This checker is created once per rule/assist execution (see call
  /// sites in `lib/src/rules/*.dart` and
  /// `lib/src/assists/wrap_with_observer_assist.dart`) and discarded when
  /// that execution ends, so this cache never grows unbounded and never
  /// keeps analyzer elements alive across analysis sessions. It is
  /// intentionally an *instance* field, not `static`, precisely so nothing
  /// here is shared across executions.
  final Map<InterfaceElement, _TypeFacts> _typeFacts =
      Map<InterfaceElement, _TypeFacts>.identity();

  /// URI prefix shared by every public and internal library of the
  /// `all_observer` package.
  static const String allObserverPackageUriPrefix = 'package:all_observer/';

  /// URI prefix shared by Flutter framework libraries, used only to detect
  /// widget lifecycle context (build methods, State, setState). Rules that
  /// only cover the reactive core must not require this to be present.
  static const String flutterPackageUriPrefix = 'package:flutter/';

  static const Set<String> _observableClassNames = {
    'Observable',
    'CoreObservable',
  };

  static const Set<String> _computedClassNames = {'Computed', 'CoreComputed'};

  static const Set<String> _observableListClassNames = {
    'ObservableList',
    'CoreObservableList',
  };
  static const Set<String> _observableMapClassNames = {'ObservableMap'};
  static const Set<String> _observableSetClassNames = {'ObservableSet'};

  static const Set<String> _observableFutureClassNames = {'ObservableFuture'};
  static const Set<String> _observableStreamClassNames = {'ObservableStream'};
  static const Set<String> _workerClassNames = {'Worker'};
  static const Set<String> _workersClassNames = {'Workers'};
  static const Set<String> _historyClassNames = {'ObservableHistory'};
  static const Set<String> _subscriptionClassNames = {'ObservableSubscription'};
  static const Set<String> _reactiveScopeClassNames = {'ReactiveScope'};

  static const Set<String> _observerWidgetClassNames = {'Observer'};

  static const Set<String> _workerFunctionNames = {
    'ever',
    'once',
    'debounce',
    'interval',
  };

  static const String _effectFunctionName = 'effect';
  static const String _batchFunctionName = 'batch';
  static const String _watchMethodName = 'watch';
  static const String _obsExtensionGetterName = 'obs';
  static const String _disposerTypeAliasName = 'Disposer';
  static const String _withHistoryMethodName = 'withHistory';
  static const String _peekMethodName = 'peek';
  static const String _untrackedFunctionName = 'untracked';

  bool _isFromAllObserver(Element? element) {
    final libraryUri = element?.library?.identifier;
    return libraryUri != null &&
        libraryUri.startsWith(allObserverPackageUriPrefix);
  }

  bool _isFromFlutter(Element? element) {
    final libraryUri = element?.library?.identifier;
    return libraryUri != null && libraryUri.startsWith(flutterPackageUriPrefix);
  }

  /// Public wrapper for [_isFromFlutter], used by widget-lifecycle helpers
  /// (see `utils/build_context_detector.dart`) that need to confirm a
  /// `BuildContext`/`Widget`/`State` element genuinely comes from Flutter,
  /// without depending on the Flutter SDK from this package's pubspec.
  bool isFlutterFrameworkElement(Element? element) => _isFromFlutter(element);

  /// Whether [element] is declared by any `package:all_observer/` library.
  bool isAllObserverElement(Element? element) => _isFromAllObserver(element);

  /// Walks the supertype chain of [type] (including mixins/interfaces)
  /// looking for a class named [names], resolved from `all_observer`.
  ///
  /// The walk itself is shared (and memoized, see [_resolveTypeFacts])
  /// across every category check for the same root element: a single
  /// traversal already collects every `all_observer`/Flutter name in the
  /// hierarchy, so this only needs to test set membership afterwards.
  bool _hasReactiveSupertypeNamed(DartType? type, Set<String> names) {
    final facts = _resolveTypeFacts(type);
    if (facts == null) return false;
    return facts.allObserverNames.any(names.contains);
  }

  bool _hasFlutterSupertypeNamed(DartType? type, String name) {
    final facts = _resolveTypeFacts(type);
    if (facts == null) return false;
    return facts.flutterNames.contains(name);
  }

  /// Returns the memoized [_TypeFacts] for [type]'s declaring element,
  /// computing and caching them on first use. Returns `null` for anything
  /// that is not an [InterfaceType] (functions, records, etc.), which never
  /// has a supertype chain to walk.
  _TypeFacts? _resolveTypeFacts(DartType? type) {
    if (type is! InterfaceType) return null;
    return _typeFacts.putIfAbsent(
      type.element,
      () => _scanTypeHierarchy(type),
    );
  }

  /// Performs the actual supertype/interface/mixin traversal exactly once
  /// per distinct [InterfaceElement], recording every `all_observer` and
  /// Flutter framework class name encountered anywhere in the hierarchy so
  /// every `is*Type` check for that same root element becomes an O(1) set
  /// lookup instead of a repeated tree walk.
  _TypeFacts _scanTypeHierarchy(InterfaceType type) {
    final visited = <InterfaceElement>{};
    final queue = <InterfaceType>[type];
    final allObserverNames = <String>{};
    final flutterNames = <String>{};
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final element = current.element;
      if (!visited.add(element)) continue;
      final name = element.name;
      if (name != null) {
        if (_isFromAllObserver(element)) allObserverNames.add(name);
        if (_isFromFlutter(element)) flutterNames.add(name);
      }
      if (element.supertype != null) queue.add(element.supertype!);
      queue.addAll(element.interfaces);
      queue.addAll(element.mixins);
    }
    return _TypeFacts(allObserverNames: allObserverNames, flutterNames: flutterNames);
  }

  // ---------------------------------------------------------------------
  // Static reactive resource creation.
  // ---------------------------------------------------------------------

  /// Whether [node] constructs an `Observable`/`CoreObservable` directly,
  /// e.g. `Observable(0)`.
  bool isObservableCreation(InstanceCreationExpression node) {
    final element = node.constructorName.type.element;
    return element is ClassElement &&
        _observableClassNames.contains(element.name) &&
        _isFromAllObserver(element);
  }

  /// Whether [node] constructs a `Computed`/`CoreComputed`, e.g.
  /// `Computed(() => ...)`.
  bool isComputedCreation(InstanceCreationExpression node) {
    final element = node.constructorName.type.element;
    return element is ClassElement &&
        _computedClassNames.contains(element.name) &&
        _isFromAllObserver(element);
  }

  /// Whether [node] constructs an `ObservableFuture`.
  bool isObservableFutureCreation(InstanceCreationExpression node) {
    final element = node.constructorName.type.element;
    return element is ClassElement &&
        _observableFutureClassNames.contains(element.name) &&
        _isFromAllObserver(element);
  }

  /// Whether [node] constructs an `ObservableStream`.
  bool isObservableStreamCreation(InstanceCreationExpression node) {
    final element = node.constructorName.type.element;
    return element is ClassElement &&
        _observableStreamClassNames.contains(element.name) &&
        _isFromAllObserver(element);
  }

  /// Whether [node] constructs an `Observer` widget.
  bool isObserverWidgetCreation(InstanceCreationExpression node) {
    final element = node.constructorName.type.element;
    return element is ClassElement &&
        _observerWidgetClassNames.contains(element.name) &&
        _isFromAllObserver(element);
  }

  bool isObserverWithChildCreation(InstanceCreationExpression node) =>
      isObserverWidgetCreation(node) &&
      node.constructorName.name?.name == 'withChild';

  bool isObservableHistoryCreation(InstanceCreationExpression node) {
    final element = node.constructorName.type.element;
    return element is ClassElement &&
        _historyClassNames.contains(element.name) &&
        _isFromAllObserver(element);
  }

  /// Whether [expression] is a `.obs` access resolved to the `all_observer`
  /// extension, e.g. `0.obs`.
  bool isObsExtensionAccess(Expression expression) {
    Element? element;
    if (expression is PropertyAccess) {
      element = expression.propertyName.element;
    } else if (expression is PrefixedIdentifier) {
      element = expression.identifier.element;
    }
    if (element is! GetterElement) {
      return false;
    }
    if (element.name != _obsExtensionGetterName) return false;
    final enclosing = element.enclosingElement;
    return enclosing is ExtensionElement && _isFromAllObserver(enclosing);
  }

  /// Any of the "creates a reactive resource" forms above, for expressions
  /// that may be either an instance creation or a `.obs` access.
  bool isAnyReactiveResourceCreation(Expression expression) {
    if (expression is InstanceCreationExpression) {
      return isObservableCreation(expression) ||
          isComputedCreation(expression) ||
          isObservableFutureCreation(expression) ||
          isObservableStreamCreation(expression);
    }
    return isObsExtensionAccess(expression);
  }

  // ---------------------------------------------------------------------
  // Function/method invocations.
  // ---------------------------------------------------------------------

  Element? _invokedElement(MethodInvocation node) => node.methodName.element;

  /// Whether [node] invokes the `effect(...)` function from `all_observer`.
  bool isEffectInvocation(MethodInvocation node) {
    final element = _invokedElement(node);
    return node.methodName.name == _effectFunctionName &&
        _isFromAllObserver(element);
  }

  /// Whether [node] invokes one of the worker functions
  /// (`ever`/`once`/`debounce`/`interval`) from `all_observer`.
  bool isWorkerInvocation(MethodInvocation node) {
    final element = _invokedElement(node);
    return _workerFunctionNames.contains(node.methodName.name) &&
        _isFromAllObserver(element);
  }

  /// Whether [node] invokes `batch(...)` from `all_observer`.
  bool isBatchInvocation(MethodInvocation node) {
    final element = _invokedElement(node);
    return node.methodName.name == _batchFunctionName &&
        _isFromAllObserver(element);
  }

  /// Whether [node] invokes `watch(context)` resolved to `all_observer`
  /// (either the extension method or a core API of the same name).
  bool isWatchInvocation(MethodInvocation node) {
    final element = _invokedElement(node);
    if (node.methodName.name != _watchMethodName) return false;
    if (_isFromAllObserver(element)) return true;
    // Extension methods resolve their enclosing element to the extension
    // itself; also check that indirection explicitly.
    if (element is MethodElement) {
      final enclosing = element.enclosingElement;
      if (enclosing is ExtensionElement && _isFromAllObserver(enclosing)) {
        return true;
      }
    }
    return false;
  }

  bool isWithHistoryInvocation(MethodInvocation node) =>
      node.methodName.name == _withHistoryMethodName &&
      _isFromAllObserver(_invokedElement(node));

  bool isPeekInvocation(MethodInvocation node) =>
      node.methodName.name == _peekMethodName &&
      _isFromAllObserver(_invokedElement(node));

  bool isUntrackedInvocation(MethodInvocation node) =>
      node.methodName.name == _untrackedFunctionName &&
      _isFromAllObserver(_invokedElement(node));

  /// Whether [node] is an effect or worker creation, for expression
  /// statements like `effect(...)`, `ever(...)`, `once(...)`,
  /// `debounce(...)`, `interval(...)`.
  bool isEffectOrWorkerInvocation(MethodInvocation node) =>
      isEffectInvocation(node) || isWorkerInvocation(node);

  /// Whether [node] calls `setState(...)`, resolved to a Flutter `State`.
  bool isSetStateInvocation(MethodInvocation node) {
    if (node.methodName.name != 'setState') return false;
    final element = _invokedElement(node);
    return _isFromFlutter(element);
  }

  // ---------------------------------------------------------------------
  // Reactive value type checks (best-effort, used for write detection).
  // ---------------------------------------------------------------------

  /// Whether [type] is (or extends) `Observable`/`CoreObservable`.
  bool isObservableType(DartType? type) =>
      _hasReactiveSupertypeNamed(type, _observableClassNames);

  /// Whether [type] is (or extends) `Computed`/`CoreComputed`.
  bool isComputedType(DartType? type) =>
      _hasReactiveSupertypeNamed(type, _computedClassNames);

  /// Whether [type] is (or extends) `ObservableList`/`CoreObservableList`.
  bool isObservableListType(DartType? type) =>
      _hasReactiveSupertypeNamed(type, _observableListClassNames);

  bool isObservableMapType(DartType? type) =>
      _hasReactiveSupertypeNamed(type, _observableMapClassNames);

  bool isObservableSetType(DartType? type) =>
      _hasReactiveSupertypeNamed(type, _observableSetClassNames);

  bool isReactiveValueType(DartType? type) =>
      isObservableType(type) ||
      isComputedType(type) ||
      isObservableListType(type) ||
      isObservableMapType(type) ||
      isObservableSetType(type);

  bool isFlutterWidgetType(DartType? type) =>
      _hasFlutterSupertypeNamed(type, 'Widget');

  /// Whether [type] is the public `Disposer` callback typedef.
  bool isDisposerType(DartType? type) {
    final alias = type?.alias?.element;
    return alias?.name == _disposerTypeAliasName && _isFromAllObserver(alias);
  }

  bool isWorkerType(DartType? type) =>
      _hasReactiveSupertypeNamed(type, _workerClassNames);

  bool isWorkersType(DartType? type) =>
      _hasReactiveSupertypeNamed(type, _workersClassNames);

  bool isObservableHistoryType(DartType? type) =>
      _hasReactiveSupertypeNamed(type, _historyClassNames);

  bool isObservableSubscriptionType(DartType? type) =>
      _hasReactiveSupertypeNamed(type, _subscriptionClassNames);

  bool isReactiveScopeType(DartType? type) =>
      _hasReactiveSupertypeNamed(type, _reactiveScopeClassNames);

  bool isObservableFutureType(DartType? type) =>
      _hasReactiveSupertypeNamed(type, _observableFutureClassNames);

  bool isObservableStreamType(DartType? type) =>
      _hasReactiveSupertypeNamed(type, _observableStreamClassNames);
}

/// The result of a single supertype/interface/mixin hierarchy walk for one
/// [InterfaceElement]: every class name found in that hierarchy that
/// resolves back to `all_observer`, and separately every class name found
/// that resolves back to the Flutter framework. A single traversal fills
/// both sets, so [AllObserverTypeChecker] never runs a separate walk per
/// category (`Observable`, `Computed`, `Widget`, ...).
class _TypeFacts {
  const _TypeFacts({required this.allObserverNames, required this.flutterNames});

  final Set<String> allObserverNames;
  final Set<String> flutterNames;
}
