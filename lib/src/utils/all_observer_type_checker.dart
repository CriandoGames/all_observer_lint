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
  const AllObserverTypeChecker();

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

  static const Set<String> _computedClassNames = {
    'Computed',
    'CoreComputed',
  };

  static const Set<String> _observableFutureClassNames = {'ObservableFuture'};
  static const Set<String> _observableStreamClassNames = {'ObservableStream'};

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

  /// Walks the supertype chain of [type] (including mixins/interfaces)
  /// looking for a class named [names], resolved from `all_observer`.
  bool _hasReactiveSupertypeNamed(DartType? type, Set<String> names) {
    if (type is! InterfaceType) return false;
    final visited = <InterfaceElement>{};
    final queue = <InterfaceType>[type];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final element = current.element;
      if (!visited.add(element)) continue;
      if (names.contains(element.name) && _isFromAllObserver(element)) {
        return true;
      }
      if (element.supertype != null) queue.add(element.supertype!);
      queue.addAll(element.interfaces);
      queue.addAll(element.mixins);
    }
    return false;
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

  /// Whether [expression] is a `.obs` access resolved to the `all_observer`
  /// extension, e.g. `0.obs`.
  bool isObsExtensionAccess(Expression expression) {
    Element? element;
    if (expression is PropertyAccess) {
      element = expression.propertyName.staticElement;
    } else if (expression is PrefixedIdentifier) {
      element = expression.identifier.staticElement;
    }
    if (element is! PropertyAccessorElement || !element.isGetter) {
      return false;
    }
    if (element.name != _obsExtensionGetterName) return false;
    final enclosing = element.enclosingElement3;
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

  Element? _invokedElement(MethodInvocation node) =>
      node.methodName.staticElement;

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
      final enclosing = element.enclosingElement3;
      if (enclosing is ExtensionElement && _isFromAllObserver(enclosing)) {
        return true;
      }
    }
    return false;
  }

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
}
