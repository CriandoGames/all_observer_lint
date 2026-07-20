// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';

import 'all_observer_type_checker.dart';

/// How a single resolved operation on an `ObservableList`/`ObservableMap`/
/// `ObservableSet` receiver relates to that collection's reactive contract.
///
/// See [ReactiveCollectionOperationClassifier] for how each case is
/// decided; the split exists so a rule can react differently to "this
/// changes the collection's contents" (`mutation`) versus "this replaces
/// the collection's entire visible content in one logical step"
/// (`replacement`), without re-deriving that distinction itself.
enum ReactiveCollectionOperationKind {
  /// Reads the collection's current contents/shape without changing it
  /// (`length`, `[]`, `contains`, `where`, iteration, ...). Registers a
  /// dependency at runtime (`reportRead()` in the real `all_observer`
  /// collections); never notifies.
  read,

  /// Mutates the collection incrementally (`add`, `remove`, `clear`,
  /// `sort`, `[]=`, ...). Notifies listeners at most once per call, per
  /// the real `all_observer` collection implementations
  /// (`notifyChanged()`).
  mutation,

  /// Replaces the entire visible content of the collection in one logical
  /// step. Today this is only `ObservableList.assign`/`.assignAll` — the
  /// real `all_observer` runtime (verified against the published source at
  /// 1.5.6, `lib/src/observable/collections/observable_map.dart` and
  /// `observable_set.dart`) does **not** expose `assign`/`assignAll` on
  /// `ObservableMap`/`ObservableSet`, unlike an earlier, unverified
  /// assumption — see `documentation/backlog.md`. Still ends in a
  /// `notifyChanged()` call underneath, but classified separately because
  /// rules like `prefer_assign_all_for_reactive_list_replace` care about
  /// the "wholesale replace" shape specifically, not just "some mutation
  /// happened".
  replacement,

  /// The operation is not one this classifier can prove is a read or a
  /// mutation: an unresolved element, or a name genuinely outside the
  /// known `all_observer` collection surface (e.g. a method added by a
  /// future `all_observer` release, or a look-alike method on an unrelated
  /// type that happens to share a name). Callers must treat this exactly
  /// like "no evidence" — per the project's false-positive policy, never
  /// assume mutation just because a method name is unrecognized.
  unknown,
}

/// Classifies operations performed on `ObservableList`/`ObservableMap`/
/// `ObservableSet` receivers as reads, incremental mutations, wholesale
/// replacements, or unknown — reusable infrastructure for every rule that
/// needs to tell a reactive-collection read apart from a write (
/// `reactive_collection_mutation`, `copied_reactive_collection_outside_tracking`,
/// and the existing purity rules once they widen beyond `.value`).
///
/// Every method name set below was read directly from the published
/// `all_observer` source (pinned version 1.5.6,
/// `lib/src/observable/collections/observable_{list,map,set}.dart`), not
/// guessed from the method's name alone — see each set's doc comment for
/// exactly which file/class was checked. Classification always requires a
/// *resolved* [Element] on the invoked method (or, for `MethodInvocation`,
/// at minimum a non-null `methodName.element`); an unresolved call is
/// [ReactiveCollectionOperationKind.unknown], never a guess.
///
/// This intentionally does not attempt to classify calls whose target is
/// not statically known to be an `ObservableList`/`ObservableMap`/
/// `ObservableSet` (via [AllObserverTypeChecker]) — those are also
/// [ReactiveCollectionOperationKind.unknown], since this classifier's only
/// job is the read/mutation/replacement distinction *given* a confirmed
/// reactive-collection receiver.
class ReactiveCollectionOperationClassifier {
  const ReactiveCollectionOperationClassifier(this._checker);

  final AllObserverTypeChecker _checker;

  /// `ObservableList` mutating members. Confirmed present — either
  /// directly overridden (`add`, `addAll`, `insert`, `insertAll`, `remove`,
  /// `removeAt`, `clear`, `sort`, `shuffle`, `removeWhere`, `retainWhere`,
  /// `addIf`, `addAllIf`, `addIfNotNull`) or reachable through the
  /// `dart:collection` `ListBase` default implementation built on top of
  /// the overridden `[]`/`[]=`/`length=` primitives (`removeLast`,
  /// `removeRange`, `setAll`, `setRange`, `replaceRange`, `fillRange`) — in
  /// both cases a call still reaches `notifyChanged()` at least once, so
  /// both are genuine mutations for this classifier's purposes even though
  /// only the first group gets a single-notification-per-call
  /// optimization in the real implementation.
  static const Set<String> _listMutationMethods = {
    'add',
    'addAll',
    'insert',
    'insertAll',
    'remove',
    'removeAt',
    'removeLast',
    'removeRange',
    'removeWhere',
    'retainWhere',
    'clear',
    'sort',
    'shuffle',
    'setAll',
    'setRange',
    'replaceRange',
    'fillRange',
    'addIf',
    'addAllIf',
    'addIfNotNull',
  };

  /// `ObservableList` wholesale-replacement members. Confirmed present as
  /// dedicated single-notification methods on the real
  /// `ObservableList` — not present on `ObservableMap`/`ObservableSet`.
  static const Set<String> _listReplacementMethods = {'assign', 'assignAll'};

  /// `ObservableMap` mutating members. `[]=` and `length=` are not method
  /// invocations (see [classifyIndexAssignment]); the rest are confirmed
  /// present either directly (`addAll`, `remove`, `clear`, `removeWhere`)
  /// or reachable through `MapBase`'s default implementation
  /// (`addEntries`, `putIfAbsent`, `update`, `updateAll`), which is itself
  /// built on the overridden `[]`/`[]=`/`remove`/`keys` primitives.
  /// `assign`/`assignAll` deliberately do **not** appear here — the real
  /// `ObservableMap` has no such members.
  static const Set<String> _mapMutationMethods = {
    'addAll',
    'addEntries',
    'putIfAbsent',
    'update',
    'updateAll',
    'remove',
    'removeWhere',
    'clear',
  };

  /// `ObservableSet` mutating members. Confirmed present either directly
  /// (`add`, `remove`, `clear`, `addAll`, `removeWhere`, `retainWhere`) or
  /// reachable through `SetBase`'s default implementation (`removeAll`,
  /// `retainAll`). `assign`/`assignAll` deliberately do **not** appear
  /// here — the real `ObservableSet` has no such members.
  static const Set<String> _setMutationMethods = {
    'add',
    'addAll',
    'remove',
    'removeAll',
    'retainAll',
    'removeWhere',
    'retainWhere',
    'clear',
  };

  /// Read-only `Iterable`/`List`/`Map`/`Set` members shared by every
  /// reactive collection, reusing the exact set already relied upon by
  /// `ReactiveReadCollector._collectionReadMethods` (kept as a separate
  /// literal here rather than importing that private set, matching this
  /// package's existing per-file convention of small, self-contained
  /// helper sets — see `documentation/backlog.md`).
  static const Set<String> _sharedReadMethods = {
    'elementAt',
    'contains',
    'containsKey',
    'containsValue',
    'indexOf',
    'lastIndexOf',
    'indexWhere',
    'lastIndexWhere',
    'join',
    'map',
    'where',
    'whereType',
    'expand',
    'fold',
    'reduce',
    'every',
    'any',
    'take',
    'takeWhile',
    'skip',
    'skipWhile',
    'followedBy',
    'toList',
    'toSet',
    'asMap',
    'getRange',
    'sublist',
    'firstWhere',
    'lastWhere',
    'singleWhere',
    'forEach',
    'lookup',
  };

  /// Read-only properties shared by every reactive collection (`length`,
  /// `keys`, `values`, `entries`, ...), mirroring
  /// `ReactiveReadCollector._collectionReadProperties`.
  static const Set<String> _sharedReadProperties = {
    'length',
    'isEmpty',
    'isNotEmpty',
    'first',
    'last',
    'single',
    'iterator',
    'reversed',
    'keys',
    'values',
    'entries',
  };

  /// Classifies a method call whose `target` may be an `ObservableList`/
  /// `ObservableMap`/`ObservableSet`. Returns
  /// [ReactiveCollectionOperationKind.unknown] when [node] has no target,
  /// the method is unresolved, or the target's static type is not a known
  /// reactive collection.
  ReactiveCollectionOperationKind classifyMethodInvocation(
    MethodInvocation node,
  ) {
    final target = node.target;
    if (target == null) return ReactiveCollectionOperationKind.unknown;
    if (node.methodName.element == null) {
      return ReactiveCollectionOperationKind.unknown;
    }

    final targetType = target.staticType;
    final name = node.methodName.name;

    if (_checker.isObservableListType(targetType)) {
      if (_listReplacementMethods.contains(name)) {
        return ReactiveCollectionOperationKind.replacement;
      }
      if (_listMutationMethods.contains(name)) {
        return ReactiveCollectionOperationKind.mutation;
      }
      if (_sharedReadMethods.contains(name)) {
        return ReactiveCollectionOperationKind.read;
      }
      return ReactiveCollectionOperationKind.unknown;
    }

    if (_checker.isObservableMapType(targetType)) {
      if (_mapMutationMethods.contains(name)) {
        return ReactiveCollectionOperationKind.mutation;
      }
      if (_sharedReadMethods.contains(name)) {
        return ReactiveCollectionOperationKind.read;
      }
      return ReactiveCollectionOperationKind.unknown;
    }

    if (_checker.isObservableSetType(targetType)) {
      if (_setMutationMethods.contains(name)) {
        return ReactiveCollectionOperationKind.mutation;
      }
      if (_sharedReadMethods.contains(name)) {
        return ReactiveCollectionOperationKind.read;
      }
      return ReactiveCollectionOperationKind.unknown;
    }

    return ReactiveCollectionOperationKind.unknown;
  }

  /// Classifies a property read/write shared by every reactive collection
  /// (currently only `length=`, a mutation on `ObservableList`; every
  /// other shared property is read-only, see [_sharedReadProperties]).
  /// [propertyName] is the accessed member name (`length`, `keys`, ...);
  /// [isWrite] must be `true` only when this access is the target of an
  /// assignment (i.e. `length =`, never a bare `length` read).
  ReactiveCollectionOperationKind classifyPropertyAccess(
    Expression target, {
    required String propertyName,
    required bool isWrite,
  }) {
    final targetType = target.staticType;
    final isKnownCollection =
        _checker.isObservableListType(targetType) ||
        _checker.isObservableMapType(targetType) ||
        _checker.isObservableSetType(targetType);
    if (!isKnownCollection) return ReactiveCollectionOperationKind.unknown;

    if (isWrite) {
      if (propertyName == 'length' &&
          _checker.isObservableListType(targetType)) {
        return ReactiveCollectionOperationKind.mutation;
      }
      return ReactiveCollectionOperationKind.unknown;
    }
    if (_sharedReadProperties.contains(propertyName)) {
      return ReactiveCollectionOperationKind.read;
    }
    return ReactiveCollectionOperationKind.unknown;
  }

  /// Classifies `target[index]` (a read) or `target[index] = value` (a
  /// mutation, `operator []=`) on an `ObservableList`/`ObservableMap`.
  /// `ObservableSet` has no index operator, so a set target is always
  /// [ReactiveCollectionOperationKind.unknown] here.
  ReactiveCollectionOperationKind classifyIndexExpression(
    IndexExpression node,
  ) {
    final target = node.target;
    if (target == null) return ReactiveCollectionOperationKind.unknown;
    final targetType = target.staticType;
    final isKnownIndexable =
        _checker.isObservableListType(targetType) ||
        _checker.isObservableMapType(targetType);
    if (!isKnownIndexable) return ReactiveCollectionOperationKind.unknown;

    if (_isWriteTarget(node)) {
      return ReactiveCollectionOperationKind.mutation;
    }
    return ReactiveCollectionOperationKind.read;
  }

  bool _isWriteTarget(Expression expression) {
    final parent = expression.parent;
    return parent is AssignmentExpression &&
        identical(parent.leftHandSide, expression);
  }
}
