import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import 'all_observer_type_checker.dart';

/// The statically proven public disposal contract for an all_observer type.
enum ReactiveDisposalKind {
  invokeCallback,
  disposeMethod,
  closeMethod,
  cancelMethod,
}

extension ReactiveDisposalKindSource on ReactiveDisposalKind {
  String invocationFor(String target) => switch (this) {
    ReactiveDisposalKind.invokeCallback => '$target();',
    ReactiveDisposalKind.disposeMethod => '$target.dispose();',
    ReactiveDisposalKind.closeMethod => '$target.close();',
    ReactiveDisposalKind.cancelMethod => '$target.cancel();',
  };

  String get memberName => switch (this) {
    ReactiveDisposalKind.invokeCallback => 'call',
    ReactiveDisposalKind.disposeMethod => 'dispose',
    ReactiveDisposalKind.closeMethod => 'close',
    ReactiveDisposalKind.cancelMethod => 'cancel',
  };
}

/// Resolves disposal from the field's static type and, only as a
/// complement (never a substitute) for that type, the shape of its
/// initializer.
///
/// The common `late final disposeEffect = effect(() {});` form has its
/// static type inferred from `effect()`'s return type, which already
/// preserves the `Disposer` alias, so [isDisposerType] alone handles it.
/// The remaining gap is a field explicitly annotated with a structural
/// function type instead of the `Disposer` alias, e.g.
/// `final void Function() disposeEffect = effect(() {});`. For that case
/// we additionally require semantic proof that the initializer is really
/// an `effect(...)` call *and* that the declared type is invocable with no
/// required arguments before treating it as disposable — a field annotated
/// with a non-invocable type (e.g. `Object`) is intentionally left
/// unresolved rather than risk emitting an invalid `field();` fix.
class ReactiveDisposalResolver {
  const ReactiveDisposalResolver(this._checker);

  final AllObserverTypeChecker _checker;

  ReactiveDisposalKind? resolve(DartType? type, [Expression? initializer]) {
    if (_checker.isDisposerType(type)) {
      return ReactiveDisposalKind.invokeCallback;
    }
    if (initializer is MethodInvocation &&
        _checker.isEffectInvocation(initializer)) {
      if (_isZeroArgumentCallableType(type)) {
        return ReactiveDisposalKind.invokeCallback;
      }
      // effect(...) resolved semantically, but the declared/inferred type
      // is not something we can safely invoke as `field();`. Stay silent
      // rather than guess.
      return null;
    }
    if (_checker.isWorkerType(type) ||
        _checker.isWorkersType(type) ||
        _checker.isObservableHistoryType(type) ||
        _checker.isReactiveScopeType(type)) {
      return ReactiveDisposalKind.disposeMethod;
    }
    if (_checker.isObservableSubscriptionType(type)) {
      return ReactiveDisposalKind.cancelMethod;
    }
    if (_checker.isComputedType(type) ||
        _checker.isObservableFutureType(type) ||
        _checker.isObservableStreamType(type)) {
      return ReactiveDisposalKind.closeMethod;
    }
    return null;
  }

  bool _isZeroArgumentCallableType(DartType? type) {
    if (type is! FunctionType) return false;
    if (type.formalParameters.any((parameter) => parameter.isRequired)) {
      return false;
    }
    return true;
  }
}
