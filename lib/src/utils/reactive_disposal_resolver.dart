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

/// Resolves disposal from the field's static type, never from initializer text.
class ReactiveDisposalResolver {
  const ReactiveDisposalResolver(this._checker);

  final AllObserverTypeChecker _checker;

  ReactiveDisposalKind? resolve(DartType? type) {
    if (_checker.isDisposerType(type)) {
      return ReactiveDisposalKind.invokeCallback;
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
}
