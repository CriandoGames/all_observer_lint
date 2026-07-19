import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'assists/wrap_with_observer_assist.dart';
import 'rules/async_inside_batch.dart';
import 'rules/avoid_effect_creation_in_build.dart';
import 'rules/avoid_io_in_computed.dart';
import 'rules/avoid_observable_write_during_observer_build.dart';
import 'rules/avoid_reactive_creation_in_build.dart';
import 'rules/avoid_reactive_write_in_computed.dart';
import 'rules/avoid_set_state_in_computed.dart';
import 'rules/avoid_worker_creation_in_computed.dart';
import 'rules/dispose_reactive_resources.dart';
import 'rules/invalid_history_limit.dart';
import 'rules/prefer_assign_all_for_reactive_list_replace.dart';
import 'rules/prefer_batch_for_multiple_related_writes.dart';
import 'rules/prefer_computed_for_derived_state.dart';
import 'rules/self_referencing_computed.dart';
import 'rules/tracking_scope_without_reactive_read.dart';
import 'rules/unobserved_reactive_read_in_build.dart';
import 'rules/unused_reactive_state.dart';
import 'rules/watch_only_inside_build.dart';

/// The `all_observer_lint` `custom_lint` plugin.
///
/// Every rule is instantiated here, unconditionally; which ones actually
/// run is controlled by the consumer's `analysis_options.yaml` (typically
/// through one of the `recommended.yaml` / `strict.yaml` / `all.yaml`
/// presets), via `custom_lint`'s own enable/disable mechanism — this class
/// does not re-implement that filtering.
class AllObserverLintPlugin extends PluginBase {
  @override
  List<Assist> getAssists() => [WrapWithObserverAssist()];

  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
    //localização e ciclo de vida.
    AvoidReactiveCreationInBuild(configs: configs),
    AvoidEffectCreationInBuild(configs: configs),
    WatchOnlyInsideBuild(configs: configs),
    DisposeReactiveResources(configs: configs),

    //pureza reativa (avoid_side_effects_in_computed split
    // into narrower, individually testable/provable rules).
    AvoidReactiveWriteInComputed(configs: configs),
    AvoidSetStateInComputed(configs: configs),
    AvoidWorkerCreationInComputed(configs: configs),
    AvoidIoInComputed(configs: configs),
    AvoidObservableWriteDuringObserverBuild(configs: configs),
    SelfReferencingComputed(configs: configs),
    InvalidHistoryLimit(configs: configs),
    AsyncInsideBatch(configs: configs),

    // Strict / experimental (info, not in recommended).
    PreferComputedForDerivedState(configs: configs),
    PreferBatchForMultipleRelatedWrites(configs: configs),
    PreferAssignAllForReactiveListReplace(configs: configs),
    UnusedReactiveState(configs: configs),
    UnobservedReactiveReadInBuild(configs: configs),
    ObserverWithoutReactiveRead(configs: configs),
    ComputedWithoutReactiveRead(configs: configs),
    EffectWithoutReactiveRead(configs: configs),
  ];
}
