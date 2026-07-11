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
  direct effect/worker/`ObservableStream` expression; disposal ownership
  transferred through a helper method is not tracked.
- `ReactiveWriteDetector` only recognizes `.value` assignment/increment/
  decrement, not broad reactive-collection mutation (`list.add(...)`,
  `map[key] = value`). The targeted `ObservableList.clear()` followed by
  `add`/`addAll` replacement pattern is covered by
  `prefer_assign_all_for_reactive_list_replace`, but general collection write
  detection remains future work.
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

## Future rules

- `avoid_large_observer_scope` (performance; mentioned as an example in
  the original severity matrix, not designed in this version).
- Broader reactive-collection-specific rules once the actual `all_observer`
  collection API is available to key checks on beyond the implemented
  `ObservableList` replacement pattern.
