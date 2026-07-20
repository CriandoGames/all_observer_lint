# Backlog

Tracks known limitations, deferred work, and rule candidates that were
deliberately not shipped yet. See each rule's own doc under
`documentation/en/rules/` and `documentation/pt-BR/rules/` for
rule-specific limitations; this file is the cross-cutting list.

## Why not one `avoid_side_effects_in_computed` rule

The original draft of this project bundled every `Computed` purity concern
into a single, broad `avoid_side_effects_in_computed` rule. "Side effect"
is too broad a category to ever prove deterministically fatal, which is a
prerequisite for anything stronger than `warning` in this project's
severity policy. It was split into:

- `avoid_reactive_write_in_computed` - narrow, testable, and the most
  plausible candidate for eventual `error` promotion once a reproducible
  `all_observer` runtime failure is documented.
- `avoid_set_state_in_computed`
- `avoid_worker_creation_in_computed`
- `avoid_io_in_computed`

Each can be evaluated, tested, and promoted independently, and a
false-positive report against one no longer requires disabling the whole
group.

## Rule candidates requiring proof before promotion to `error`

None of the below may become `error` without: a reproducible minimal example,
a named violated invariant, a runtime regression test in the `all_observer`
repository itself, a lint-side test suite (positive/negative/aliases/
subclasses), and a documented technical review.

- **`self_referencing_computed`** - implemented in v0.1.0 as an `error` for
  direct self-dependencies where a `Computed(...)` assigned to a variable/field
  reads that same symbol's `.value` inside its callback. Longer computed cycles
  such as `a -> b -> a` remain future work.
- **`unconditional_reactive_write_during_observer_build`** - the subset of
  `avoid_observable_write_during_observer_build` where the write is
  unconditional and targets a dependency the same callback unconditionally
  reads. See that rule's doc for why it wasn't split out yet.
- **`observable_write_during_computed` (stricter form)** - same idea for
  `avoid_reactive_write_in_computed`: needs proof of whether the write
  causes unbounded recomputation, is intercepted by the runtime, or
  silently no-ops, before any subset of it can move to `error`.

## Detection coverage gaps

All current severities stay accurate; these are false-negative risks, not
false-positive risks.

- Reactive resource creation/effect registration hidden behind a factory
  or helper function called from `build` is not detected
  (`avoid_reactive_creation_in_build`, `avoid_effect_creation_in_build`).
- `dispose_reactive_resources` only tracks fields whose initializer is a
  direct effect/worker/`ObservableStream` expression. Disposal ownership
  transferred through a helper method *is* followed, but only narrowly: a
  same-class, zero-parameter method called via a bare or `this.` target
  (`_disposeResources()`, `this._disposeResources()`), one level or chained
  through further zero-parameter helpers. A helper that takes a parameter
  (e.g. `_disposeWith(worker)`), lives in a different class/mixin, or is
  reached only through a tear-off, is not followed — the field is still
  flagged in those cases.
- **Resolved (Etapa B, assisted-migrations phase):** `ReactiveWriteDetector`
  now also recognizes reactive-collection mutations/replacements
  (`list.add(...)`, `map['k'] = v`, `list.length = n`, `list.assignAll(...)`,
  ...) via `ReactiveCollectionOperationClassifier`, in addition to `.value`
  assignment/increment/decrement — so `avoid_reactive_write_in_computed` and
  `avoid_observable_write_during_observer_build` now catch both. The
  targeted `ObservableList.clear()` followed by `add`/`addAll` replacement
  pattern remains separately covered by
  `prefer_assign_all_for_reactive_list_replace`.
  Still not widened: `prefer_batch_for_multiple_related_writes` only counts
  `.value` writes toward its "multiple related writes" heuristic, not
  collection mutations — tracked as follow-up work, not attempted in Etapa B
  to keep that change reviewable on its own (widening a `strict`-only,
  info-level rule's heuristic carries different risk than widening the two
  `recommended`, `warning`-level purity rules).
- `avoid_io_in_computed` only recognizes `dart:io` and `await`; common HTTP
  client packages, platform channels, and database packages are not covered.
- A closure that is textually nested inside a `Computed` callback but only
  runs asynchronously/deferred (for example, `Future(...).then(...)`) is still
  treated as "inside" the callback by `ComputedCallbackFinder`. This can
  produce a false positive in that specific, fairly rare shape; documented
  per-rule.

## Dependency resolution

- **Resolved:** the initial `custom_lint_builder: ^0.6.4` /
  `custom_lint_core: ^0.6.4` pin failed `pub get` on a real machine with
  `could not find package _macros in the Dart SDK`. Root cause: analyzer
  versions in the `custom_lint_core` 0.6.5-0.6.10 range depended on a
  `macros` package version that required a `_macros` package bundled only
  in certain Dart SDK builds, not present on a plain stable SDK. That was
  fixed at the time by moving to the `custom_lint_builder` 0.7 series.
- **Resolved:** `custom_lint_builder 0.8.1` constrains the effective analyzer
  compatibility to analyzer 8. Because this package imports `package:analyzer`
  directly, its public constraint is `analyzer: ">=8.0.0 <9.0.0"` instead of
  advertising broader analyzer major support.
- **Resolved:** lower-bound tests on current Dart SDKs require
  `frontend_server_client >=4.0.0`; the older lower-bound selected through
  `test` tried to invoke a removed `frontend_server.dart.snapshot`.

## Infrastructure follow-ups

- **Resolved:** presets and localization now use the `custom_lint.rules`
  configuration shape that `custom_lint` actually exposes to plugins. Earlier
  documentation used a top-level `all_observer:` key inspired by standalone
  linters such as `bloc_lint`, but that key is invisible to `CustomLintConfigs`.
- **Plugin wiring smoke test.** `test/all_observer_lint_test.dart` only
  checks `createPlugin()` returns a `PluginBase`. CI now also runs lower-bound
  resolution, and the example project is used as a real analyzer/custom_lint
  loading smoke test during release checks.
- **Real `all_observer` verification.** Every library URI, class name, and
  extension name this package keys on (`AllObserverTypeChecker`) should be
  kept in sync with the actual published `all_observer` public API before
  each compatibility release.
- **CI matrix.** `.github/workflows/ci.yml` currently uses stable plus a
  separate lower-bounds job. Expanding to an explicit minimum-supported SDK
  matrix remains future work.

## Remaining items from the 0.5.1 stabilization pass

The 0.5.1 patch addressed the `Wrap with Observer` collision/shadowing gap,
the `effect()`-without-`Disposer`-annotation gap in `dispose_reactive_resources`,
the `fake_all_observer` API divergences (`debounce`/`interval` requiring
`time:`, `ObservableList`/`ObservableMap`/`ObservableSet` shape), the
helper/nested-closure false positives in the `*_without_reactive_read` rules,
reactive collection reads beyond `.value`/`length`/etc. (`map`/`where`/`any`/
`every`/`contains`/`join`/`for-in`/spread/`keys`/`values`/`entries`, all
verified against the collection base-class shape of real `all_observer`
1.5.6), a real-`all_observer` smoke test (`test/fixtures/real_runtime_smoke`,
pinned to `all_observer: ">=1.5.6 <1.6.0"`, with its own CI job that
analyzes, lints, applies the `dispose_reactive_resources` fix, and
re-analyzes/re-lints to prove the diagnostic disappears — every signature it
exercises, e.g. `debounce`/`interval` requiring `time:`, `effect`'s
`Disposer` return type, `ObservableList extends ListBase`, was read directly
from the published source at the pinned version, not guessed), and CI
verification of applied fixes (`dart format` + `dart analyze` + re-run
`custom_lint` after `--fix`, both for the fake-runtime and real-runtime
smoke jobs). Also addressed since: `Observer.withChild` builder-vs-child
tracking now has dedicated tests (`observer_with_child_tracking.dart`)
proving a read in `child` never counts toward the `builder`'s own tracking
scope, and `dispose_reactive_resources` now follows disposal delegated to a
same-class, zero-parameter helper method (directly or chained through
further such helpers) — see "Detection coverage gaps" above for the exact,
deliberately narrow scope of that. Still open from that review:

- **Resolved (this task).** "Mixed `watch(context)` + `.value` in the same
  expression" no longer needs a special case: `Wrap with Observer` is now
  permissive by design (see `documentation/architecture.md`, "`Wrap with
  Observer`: permissive by design") and no longer inspects reads at all, so
  this combination — like every other Widget expression — is simply
  available. Judging whether the combination is redundant is left to the
  opt-in `observer_without_reactive_read`/`unobserved_reactive_read_in_build`
  lints.
- **Resolved:** `test/runtime_contract/fake_runtime_contract_test.dart` now
  asserts, via a lightweight source-text check that needs no network access,
  that `fake_all_observer` still declares the exact signatures verified
  against the real package for 0.5.1 (`debounce`/`interval`'s required
  `time:`, `ObservableList`/`Map`/`Set`'s `dart:collection` base classes,
  the `Disposer` alias and `effect()`'s return type, `Observer`/
  `Observer.withChild`, `assign`/`assignAll`). It is deliberately narrow —
  a string check, not full semantic re-verification — so it catches an
  accidental revert of one of these signatures, not every possible drift;
  `test/fixtures/real_runtime_smoke` remains the actual proof against the
  live package.
- **`all_observer_lint.dart`/format check scope.** The CI formatting check
  only covers `lib/`, not `test/`; the many hand-authored test fixtures in
  this repo have not been verified against `dart format` line-for-line
  (existing golden-comparison tests already run fixtures they *transform*
  through `dart format`, but plain, never-transformed fixtures have not
  been re-checked).

## Wrap with Observer / performance task (this change)

- **`const`-chain rewriting.** `Wrap with Observer` still declines to fire
  when the selection is in a constant context. There is no safe, general
  transformation of the surrounding `const` chain implemented (removing
  `const` from every ancestor that requires it would be a much larger,
  separately-reviewed change) — out of scope per the task brief
  ("remoção automática de `const`"). Tracked here as future work, not a
  bug.
- **`RebuildScopeFinder` cache.** `lib/src/utils/build_context_detector.dart`
  was intentionally left unchanged. The brief only asked for this cache "se
  os benchmarks mostrarem ganho mensurável," and the assist itself no longer
  calls `RebuildScopeFinder` at all (see `documentation/architecture.md`).
  The rules that still use it (`avoid_reactive_creation_in_build`,
  `avoid_effect_creation_in_build`, `watch_only_inside_build`,
  `avoid_observable_write_during_observer_build`) each call `find`/
  `findObserverScope` a bounded, small number of times per file (once per
  creation-site/write-site candidate, not once per reactive read), so there
  was no benchmark evidence of a repeated-ancestor-walk hot path to justify
  adding a cache. Revisit if a future rule calls it per-read instead of
  per-candidate.
- **Cross-file `unused_reactive_state`.** The reference index introduced in
  this task (`ReactiveReferenceIndex`) is still scoped to a single
  `CompilationUnit`, matching the rule's existing, deliberate single-file
  scope. Widening it to cross-file references remains explicitly out of
  scope (see the task brief, "não ampliar o escopo para referências entre
  arquivos nesta mudança").

## Assisted-migrations phase — real-runtime audit notes (Etapa A)

Before writing `ReactiveCollectionOperationClassifier` and
`UnitSemanticIndex`, the real, published `all_observer` source (pinned
`1.5.6`, the same version `test/fixtures/real_runtime_smoke` targets) was
re-read directly for every collection/effect/worker/scope/async API this
phase touches. Two corrections against the phase's own illustrative brief:

- **`ObservableMap`/`ObservableSet` do not have `assign`/`assignAll`.**
  Only `ObservableList` does
  (`lib/src/observable/collections/observable_list.dart` in the real
  package). The classifier's `_mapMutationMethods`/`_setMutationMethods`
  sets deliberately do not include them; a rule that assumed otherwise
  would silently never fire for Map/Set (safe) or, worse, suggest a
  non-existent method (unsafe) — this was caught before either could
  happen.
- **`ObservableList` also has `addIf`, `addAllIf`, `addIfNotNull`** —
  convenience mutators not previously tracked anywhere in this package.
  Added to the classifier's mutation set.
- **`effect()` runs its body immediately, synchronously, on creation** —
  confirmed in `lib/src/effects/effect.dart`. A plain
  `observable.addListener(callback)` (or `Observable.listen(callback)`,
  default `immediate: false`) does *not* run immediately. This means
  "convert `addListener` to `effect`" is **not** a behavior-preserving
  transformation in general — the callback would gain an extra immediate
  invocation it never had. `ever(observable, callback)` (built on
  `Observable.listen` with the same `immediate: false` default) *is*
  behavior-preserving for the "runs only on future changes" shape. The
  listener-to-`effect`/`ever` migration analyzer (Etapa in progress) must
  offer these as two distinct, separately-justified actions ("Convert
  listener to effect" vs. "Convert listener to ever worker") exactly as
  the phase brief requires, and must not default to `effect` just because
  it is the more general primitive.
- **`Observable`/`Computed` both `implements ValueListenable<T>` in the
  real package** (`lib/src/observable/observable.dart`,
  `lib/src/observable/computed.dart`), including working
  `addListener`/`removeListener`. `test/fixtures/fake_all_observer` does
  **not** yet model this (its `Observable`/`Computed` have no
  `addListener`/`removeListener` at all) — a pre-existing gap, not
  introduced by this phase. Practical implication verified against the
  real source: a `ValueNotifier` field converted to an `Observable` and
  left wired into an unchanged `ValueListenableBuilder` continues to
  compile and behave correctly, since `Observable` already satisfies
  `ValueListenable` — the illustrative brief's assumption that a
  `ValueListenableBuilder` consumer must always block the `ValueNotifier`→
  `Observable` conversion is stricter than the real runtime requires. The
  `ValueNotifier` migration analyzer (Etapa E) should treat a
  `ValueListenableBuilder`-only consumer as compatible, not as a blocking
  case, and document this explicitly rather than silently following the
  brief's more conservative illustration.
- **Follow-up needed before Etapa E's fixtures can exercise
  `Observable`/`Computed` as listener targets end-to-end:**
  `test/fixtures/fake_all_observer` needs `Observable`/`Computed` to
  `implements ValueListenable<T>` with real `addListener`/`removeListener`,
  matching the real package. Deliberately not done in Etapa A to keep that
  change's blast radius limited to new files plus a small, additive
  `AllObserverTypeChecker` extension — every existing fixture and rule
  test keeps resolving exactly as before. `UnitSemanticIndex`'s
  `listenerRegistrations`/`listenerRemovals` capability is tested today
  only against plain Flutter `ValueNotifier`/`ChangeNotifier` targets,
  which already exercise the same `isFlutterListenableType` code path.

## Future rules

- `avoid_large_observer_scope` (performance; mentioned as an example in
  the original severity matrix, not designed in this version).
- Broader reactive-collection-specific rules once the actual `all_observer`
  collection API is available to key checks on beyond the implemented
  `ObservableList` replacement pattern.

## Current resolutions and deferred transformations

The plugin wiring and real-runtime verification items above are resolved for
this change: CI now uses `test/fixtures/smoke` with `dart run custom_lint`,
including a temporary runner-applied fix, and disposal/Observer/history/batch/
async/scope/worker/subscription contracts were checked against the sibling
runtime. Repeat runtime verification before each compatibility release.

Still deferred:

- **Resolved (Etapa C):** minimum-reactive-subtree wrapping, via the new
  `WrapSmallestReactiveSubtreeAssist`
  (`lib/src/assists/wrap_smallest_reactive_subtree_assist.dart`), offered
  alongside the existing permissive `Wrap with Observer` assist rather than
  replacing it. Still out of scope for this specialized action (the
  permissive assist remains the manual fallback in these cases):
  - only a `.value` read of `Observable`/`Computed` is recognized as the
    anchoring read — reactive-collection reads (`items.length`,
    `items.contains(...)`) and `watch(context)` are not yet supported as
    triggers;
  - automatic *Observer scope reduction* (shrinking an already-existing,
    too-broad `Observer` wrap down to a smaller one) is not attempted —
    this assist only ever introduces a new wrap, it never edits/replaces an
    existing `Observer`;
  - the "already exactly the root of an enclosing `Observer` builder" check
    is deliberately duplicated from `wrap_with_observer_assist.dart` rather
    than factored into a shared helper, trading a small amount of code
    duplication for zero risk to that already-tested assist. Revisit this
    if a third assist ever needs the same check.
- `setState`, `ValueNotifier`, `ChangeNotifier`, listener, Future, Stream, and
  complete `AsyncState` migrations;
- Observable-to-plain-value conversion and cross-file migrations;
- **Resolved (Etapa B):** reactive-collection mutation detection (List/Map/
  Set) integrated into the existing purity rules, and a new
  `copied_reactive_collection_outside_tracking` rule (`strict`/`all`,
  `info`) detecting a `.toList()`/`.toSet()` snapshot read inside a tracking
  scope instead of the original collection. Still out of scope for that
  rule: spread-literal snapshots (`[...items]`), field (non-local) snapshots,
  and any assist/quick fix (diagnostic only) — see
  `documentation/en/rules/copied_reactive_collection_outside_tracking.md`,
  "Limitations".
- snippets, completion, custom hover, and fix-on-save, which need
  editor-specific integration beyond portable `custom_lint`;
- DevTools, which needs runtime protocol and UI work;
- `observer_scope_too_large`, `expensive_equals`, and
  `throwing_batch_contract`, which need measurable evidence and precise
  semantic contracts.
