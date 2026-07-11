import 'diagnostic_message_key.dart';
import 'diagnostic_messages.dart';

/// English diagnostic messages. This is the default and canonical locale.
class DiagnosticMessagesEn implements DiagnosticMessages {
  const DiagnosticMessagesEn();

  static const Map<DiagnosticMessageKey, String> _messages = {
    DiagnosticMessageKey.reactiveCreationInsideBuild:
        'Avoid creating reactive state inside build. The resource will be '
        'recreated whenever the widget rebuilds. Move it to a State field, '
        'initState, controller, view model, or another lifecycle-managed '
        'object.',
    DiagnosticMessageKey.effectCreationInsideBuild:
        'Avoid registering effects or workers inside build. Rebuilds may '
        'create duplicate subscriptions. Register the resource in a '
        'lifecycle-managed location and dispose it when appropriate.',
    DiagnosticMessageKey.invalidWatchContext:
        'Use watch(context) only while building a widget. Outside build, '
        'read value directly or use an explicit listener/effect.',
    DiagnosticMessageKey.reactiveResourceNotDisposed:
        'This reactive resource is not disposed. Dispose it with the owning '
        'lifecycle to prevent stale listeners and duplicated side effects.',
    DiagnosticMessageKey.reactiveWriteInsideComputed:
        'Do not write to a reactive value inside a Computed callback. '
        'Computed must derive a value without mutating reactive state; move '
        'the write to an action, effect, or worker.',
    DiagnosticMessageKey.setStateInsideComputed:
        'Do not call setState inside a Computed callback. Computed callbacks '
        'may run outside the widget lifecycle and must not touch widget '
        'state directly.',
    DiagnosticMessageKey.workerCreationInsideComputed:
        'Do not create effects or workers inside a Computed callback. '
        'Computed can be recomputed multiple times, which would register '
        'duplicate subscriptions.',
    DiagnosticMessageKey.ioInsideComputed:
        'Avoid I/O calls inside a Computed callback. Computed callbacks can '
        'run synchronously and repeatedly during dependency tracking, which '
        'makes I/O here unpredictable and wasteful.',
    DiagnosticMessageKey.observableWriteDuringObserverBuild:
        'Avoid mutating reactive state while an Observer is building. Keep '
        'rendering callbacks read-only and perform state changes in '
        'actions, event handlers, effects, or controllers.',
    DiagnosticMessageKey.selfReferencingComputed:
        'A Computed value cannot read its own value inside its callback. This '
        'creates a reactive cycle that cannot stabilize; derive from other '
        'reactive values instead.',
    DiagnosticMessageKey.preferComputedForDerivedState:
        'This observable appears to be manually kept in sync with other '
        'observables. Consider deriving it with Computed instead of '
        'assigning it by hand.',
    DiagnosticMessageKey.preferBatchForMultipleRelatedWrites:
        'Multiple related reactive writes happen here without batch. If '
        'external listeners observe intermediate states, consider wrapping '
        'these writes in Observable.batch(() { ... }).',
    DiagnosticMessageKey.preferAssignAllForReactiveListReplace:
        'Prefer assignAll(...) or assign(...) when replacing an ObservableList. '
        'Calling clear() and then add/addAll notifies in two separate '
        'steps and can expose an intermediate empty list.',
  };

  @override
  String message(DiagnosticMessageKey key) => _messages[key] ?? key.toString();
}
