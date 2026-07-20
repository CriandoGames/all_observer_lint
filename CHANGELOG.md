# Changelog

## 0.6.1

Bug fix: `Introduce ReactiveScope` could rewrite an inferred (never
explicitly annotated) `effect()`-backed `Disposer` field using `Disposer`
as its new explicit type. That alias is not exported from the real
`all_observer` package's public surface, so the generated field failed to
resolve (`undefined_class`) against real code, even though it compiled
fine against this package's own test fixture. The assist now uses the
underlying structural type (`void Function()`) instead whenever no
explicit type was already present. See `documentation/architecture.md`/
`backlog.md` for the full root cause. No other rule/assist/preset
changed.

## 0.6.0

`Wrap with Observer` is now permissive (any Widget selection, not just
reads); read-quality judgment stays with the opt-in lints. Performance:
per-execution type-hierarchy memoization, plus one-time indices for
`unused_reactive_state`/`dispose_reactive_resources`. New rule:
`copied_reactive_collection_outside_tracking` (`strict`/`all`, info);
the two write-purity rules now also catch reactive-collection mutations.
Five new assists — wrap smallest reactive subtree, extract to `Computed`,
convert `ValueNotifier`/`ChangeNotifier` field to `Observable`, introduce
`ReactiveScope` — all assist-only, no preset change; `AsyncState` deferred.
Two regressions found and fixed along the way: a compound-assignment
tracking gap and a missed `FunctionExpressionInvocation`-shaped disposal
call. See `documentation/architecture.md`/`backlog.md` for full details.

## 0.5.1

Stabilization patch, addressing the P0/P1 findings from the pre-publication
review of 0.5.0 (see `documentation/backlog.md`):

- `Wrap with Observer` no longer assumes a bare `Observer(...)` reference is
  safe just because an `all_observer` import exists or can be added. The
  assist now checks for a same-named top-level declaration in the file, a
  locally-shadowing parameter/variable at the selection point, and any other
  unprefixed import that might also expose an `Observer` name, falling back
  to a freshly generated, uniquely-named prefixed import
  (e.g. `allObserver.Observer`, `allObserver2.Observer`) whenever any of
  those are detected. This means the assist is now available (via a safe
  prefixed import) in some cases where it previously stayed unavailable.
- `dispose_reactive_resources` and its quick fix now also recognize
  `effect(...)` stored without an explicit `Disposer` annotation
  (`late final disposeEffect = effect(() {});`) and, when the initializer is
  proven to be `effect(...)` but the declared type is a non-`Disposer`
  structural function type, only apply the callback-invocation fix when that
  type is actually invocable with no required arguments — a field typed as
  `Object` (or anything else non-invocable) is left unresolved rather than
  risking an invalid `field();` fix.
- `observer_without_reactive_read`, `computed_without_reactive_read`, and
  `effect_without_reactive_read` are now more conservative about proving a
  tracking scope has *no* reactive read at all: a helper call reached
  through `this`/an instance target/a static target (previously only bare
  calls were treated this way), and a nested closure (e.g. inside `.map`),
  are now both treated as a potential hidden read and suppress the
  diagnostic, instead of being silently ignored. Calls resolved to
  `dart:core`/other SDK libraries (e.g. `toString()`) are explicitly
  excluded from this so proven-empty scopes are still flagged.
- The `fake_all_observer` test fixture (used only by this package's own test
  suite, never shipped) was updated to match the real `all_observer` public
  surface more closely: `debounce`/`interval` now require the named `time:`
  parameter (previously optional with a default), `ObservableList<E>` now
  extends `ListBase<E>` instead of wrapping a `CoreObservable<List<E>>`
  (matching how the real package models it, which affects static-type-based
  member resolution, iteration, and collection literals), and
  `ObservableMap`/`ObservableSet` fakes and `.obs` extensions were added.
- `observer_without_reactive_read`/`computed_without_reactive_read` no
  longer under-report on a tracking scope that only iterates or queries a
  reactive collection: `ReactiveReadCollector` now also recognizes
  `map`/`where`/`whereType`/`expand`/`fold`/`reduce`/`every`/`any`/
  `contains`/`containsKey`/`containsValue`/`indexOf`/`lastIndexOf`/
  `indexWhere`/`lastIndexWhere`/`join`/`take`/`takeWhile`/`skip`/
  `skipWhile`/`followedBy`/`toList`/`toSet`/`asMap`/`getRange`/`sublist`/
  `firstWhere`/`lastWhere`/`singleWhere`/`elementAt`/`forEach` calls, plain
  `for-in` iteration, and collection-literal spreads (`...items`), on
  `ObservableList`/`ObservableMap`/`ObservableSet` as reads — matching how
  the real collections actually register dependencies at runtime (through
  their own `length`/`[]`).
- Added `test/fixtures/real_runtime_smoke`, a fixture pinned to the real,
  published `all_observer` package (`>=1.5.6 <1.6.0`) rather than this
  repo's `fake_all_observer` stand-in, wired into a new CI job. It analyzes
  and lints a file exercising `Observable`, `Computed`, `effect`, all four
  workers, `ObservableSubscription`, `ObservableHistory`, `ReactiveScope`,
  `ObservableFuture`/`ObservableStream`, `Observer`/`Observer.withChild`,
  `watch(context)`, and the reactive collections against the real package,
  then applies the `dispose_reactive_resources` quick fix to a file using
  the inferred-`Disposer` form and re-analyzes/re-lints to prove the
  diagnostic disappears and no invalid `.dispose()` call was generated —
  the first proof this package's rules and fixes behave correctly against
  the actual published `all_observer` API (every signature the fixture
  relies on, e.g. `debounce`/`interval`'s required `time:`, was read
  directly from the package source at the pinned version).
- CI now also checks `dart format` on `lib/`, and both smoke jobs
  (fake-runtime and real-runtime) re-run `dart format` + `dart analyze` +
  `custom_lint` after applying the `dispose_reactive_resources` fix, failing
  if the diagnostic is still reported — previously only each Dart test's own
  golden comparison verified a fix's output, with no equivalent end-to-end
  check in CI.
- Added dedicated `observer_without_reactive_read` coverage proving
  `Observer.withChild` is tracked correctly: only its `builder` callback is
  inspected, never the `child` argument — a reactive read that appears only
  in `child` still counts as the builder having zero reactive reads, since
  `child` is built once and is never responsible for a rebuild.
- `dispose_reactive_resources` now follows disposal delegated to a
  same-class, zero-parameter helper method (`_disposeResources()`,
  `this._disposeResources()`), directly or chained through further such
  helpers, instead of only ever looking for the disposal call written
  directly in `dispose()`. Deliberately narrow: a helper that takes a
  parameter, lives outside the class, or is reached only through a
  tear-off is not followed, so the field is still flagged in those cases.
- Added `test/runtime_contract/fake_runtime_contract_test.dart`: a
  network-free check that `fake_all_observer` still declares the exact
  signatures verified against the real package for this release
  (`debounce`/`interval`'s required `time:`, the collections'
  `dart:collection` base classes, `Disposer`/`effect()`, `Observer`/
  `Observer.withChild`, `assign`/`assignAll`), so an accidental future
  revert of the fake's shape is caught immediately instead of only at the
  next manual audit.

## 0.5.0

- Fixed `dispose_reactive_resources` and its quick fix to use resolved disposal
  contracts: callback invocation, `dispose()`, `close()`, or `cancel()`.
- Added the `Wrap with Observer` assist with semantic Widget/read checks,
  callback/tracking/const guards, and safe import handling.
- Added recommended warnings `invalid_history_limit` and `async_inside_batch`.
- Added strict/all info diagnostics `observer_without_reactive_read`,
  `computed_without_reactive_read`, and `effect_without_reactive_read`.
- Added full-file golden transformation tests, post-edit formatting and
  reanalysis, idempotency checks, and a real `custom_lint` runner smoke project.

## 0.4.0

Breaking configuration change:

- Presets and localization now use `custom_lint.rules`, the configuration
  shape exposed by `custom_lint`. Projects that configured Portuguese messages
  with a top-level `all_observer:` key must move that option under
  `custom_lint.rules`:

  ```yaml
  custom_lint:
    rules:
      - all_observer:
        language: pt-BR
  ```

Fixes and improvements:

- Fixed Brazilian Portuguese diagnostic opt-in documentation and tests.
- `recommended.yaml`, `strict.yaml`, and `all.yaml` now explicitly disable
  unspecified lint rules so each preset enables only its intended rules.
- Added a quick fix for `prefer_batch_for_multiple_related_writes` that wraps
  consecutive reactive writes in `Observable.batch(() { ... });`.
- Fixed `prefer_batch_for_multiple_related_writes` so it no longer reports
  writes that are already inside `Observable.batch`.
- Added the strict/all `unused_reactive_state` rule for private reactive fields
  and top-level variables that are never referenced in the same file.
- Added the strict/all `unobserved_reactive_read_in_build` rule for reactive
  `.value` reads rendered in `build` without `Observer` or `watch(context)`.

## 0.3.0

Documentation-only update. No changes to rule behavior, presets, or the
public API.

- Synced `README.md`/`README.pt-BR.md` install snippets and compatibility
  notes with the 0.2.0 toolchain bump (Dart SDK `>=3.10.0`, `analyzer 8.x`,
  `custom_lint_builder 0.8.1`), including the `custom_lint`/
  `all_observer_lint` version pins shown in the install examples.

## 0.2.0

Compatibility release for the current Dart/custom_lint toolchain.

- Raised the minimum Dart SDK to `>=3.10.0 <4.0.0`.
- Updated lint tooling constraints for `custom_lint_builder 0.8.x` and
  `analyzer 8.x`.
- Migrated internal analyzer API usage to the current element model.
- No rule behavior changes.

## 0.1.0

First public release of `all_observer_lint`.

This version introduces the official lint package for teams building with
`all_observer`. It focuses on the mistakes that are hardest to notice during
day-to-day development: reactive resources created in rebuild paths, effects
registered repeatedly, impure `Computed` callbacks, unsafe writes while UI is
building, invalid `watch(context)` usage, and missing disposal for long-lived
reactive resources.

The goal of this first release is simple: help developers catch real reactive
bugs earlier, directly in the IDE, without adding anything to the application
runtime.

### Highlights

- Official `custom_lint` plugin for `all_observer`.
- Ready-to-use presets:
  - `recommended.yaml` for everyday projects.
  - `strict.yaml` for additional design guidance.
  - `all.yaml` for evaluating every available rule.
- Diagnostics in English by default.
- Brazilian Portuguese diagnostics with:

  ```yaml
  custom_lint:
    rules:
      - all_observer:
        language: pt-BR
  ```

- Quick fix support for missing disposal of reactive resources.
- Error-level protection for direct self-referencing `Computed` values.
- Example Flutter app with flagged and fixed patterns.
- Bilingual rule documentation.

### Rules Included

Recommended rules:

- `avoid_reactive_creation_in_build`
- `avoid_effect_creation_in_build`
- `watch_only_inside_build`
- `dispose_reactive_resources`
- `avoid_reactive_write_in_computed`
- `avoid_set_state_in_computed`
- `avoid_worker_creation_in_computed`
- `avoid_io_in_computed`
- `avoid_observable_write_during_observer_build`
- `self_referencing_computed`

Strict rules:

- `prefer_computed_for_derived_state`
- `prefer_batch_for_multiple_related_writes`
- `prefer_assign_all_for_reactive_list_replace`

### Why It Matters

`all_observer` tracks dependencies automatically when reactive values are read
inside tracked contexts such as `Observer`, `Computed`, `effect`, and
`watch(context)`. Small mistakes around where resources are created, where
state is mutated, or when subscriptions are disposed can lead to duplicated
listeners, repeated side effects, lost state, stale observers, or unpredictable
UI updates.

The strict preset also includes a targeted `ObservableList` replacement rule:
when code calls `clear()` and immediately follows with `add` or `addAll`, the
lint suggests `assign` or `assignAll` so replacement happens as one logical
operation.

`all_observer_lint` turns those patterns into actionable feedback while the
developer is still writing the code.

### Documentation

- README: installation, setup, examples, presets, and rule list.
- `README.pt-BR.md`: Portuguese version.
- `documentation/en/rules/`: English rule documentation.
- `documentation/pt-BR/rules/`: Portuguese rule documentation.
- `documentation/architecture.md`: implementation notes and semantic matching.
- `documentation/backlog.md`: known limitations and future rule candidates.
- `documentation/false_positives.md`: false-positive policy and known tradeoffs.

### Notes

- Most v0.1.0 recommended rules are intentionally conservative warnings.
- `self_referencing_computed` ships as `error` because it detects a direct
  reactive cycle.
- Future error-level rules will require reproducible evidence and dedicated
  documentation.
- The package is development-only and does not add runtime dependencies to apps.
