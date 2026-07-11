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
severity policy (section 22–25 of the brief). It was split into:

- `avoid_reactive_write_in_computed` — narrow, testable, and the most
  plausible candidate for eventual `error` promotion once a reproducible
  `all_observer` runtime failure is documented.
- `avoid_set_state_in_computed`
- `avoid_worker_creation_in_computed`
- `avoid_io_in_computed`

Each can be evaluated, tested, and promoted independently, and a
false-positive report against one no longer requires disabling the whole
group.

## Rule candidates requiring proof before promotion to `error`

Per section 23 of the brief, none of the below may become `error` without:
a reproducible minimal example, a named violated invariant, a runtime
regression test in the `all_observer` repository itself, a lint-side test
suite (positive/negative/aliases/subclasses), and a documented technical
review answering the eight questions in section 23.5.

- **`self_referencing_computed`** — a `Computed` that reads its own
  `.value` inside its derivation. Strong candidate per the brief (section
  26.2): if `all_observer` really throws `ObserverCycleError` for this
  deterministically, in every supported version, this is close to
  provable. Not implemented in this version — needs a runtime test against
  the real `all_observer` first, which requires access to that repository
  and its test suite. Would live in the `reactive-cycle` category.
- **`unconditional_reactive_write_during_observer_build`** — the subset of
  `avoid_observable_write_during_observer_build` where the write is
  unconditional and targets a dependency the same callback unconditionally
  reads. See that rule's doc for why it wasn't split out yet.
- **`observable_write_during_computed` (stricter form)** — same idea for
  `avoid_reactive_write_in_computed`: needs proof of whether the write
  causes unbounded recomputation, is intercepted by the runtime, or
  silently no-ops, before any subset of it can move to `error`.

## Detection coverage gaps (all current severities stay accurate; these are false-negative risks, not false-positive risks)

- Reactive resource creation/effect registration hidden behind a factory
  or helper function called from `build` is not detected
  (`avoid_reactive_creation_in_build`, `avoid_effect_creation_in_build`).
- `dispose_reactive_resources` only tracks fields whose initializer is a
  direct effect/worker/`ObservableStream` expression; disposal ownership
  transferred through a helper method is not tracked.
- `ReactiveWriteDetector` only recognizes `.value` assignment/increment/
  decrement, not reactive-collection mutation (`list.add(...)`,
  `map[key] = value`). Extending this requires the real `all_observer`
  reactive-collection API surface, which is not fully specified in this
  project's brief.
- `avoid_io_in_computed` only recognizes `dart:io` and `await`; common HTTP
  client packages, platform channels, and database packages are not
  covered.
- A closure that is textually nested inside a `Computed` callback but only
  runs asynchronously/deferred (e.g. `Future(...).then(...)`) is still
  treated as "inside" the callback by `ComputedCallbackFinder`. This can
  produce a false positive in that specific, fairly rare shape; documented
  per-rule.

## Dependency resolution

- **Resolved:** the initial `custom_lint_builder: ^0.6.4` /
  `custom_lint_core: ^0.6.4` pin failed `pub get` on a real machine with
  `could not find package _macros in the Dart SDK`. Root cause: analyzer
  versions in the `custom_lint_core` 0.6.5–0.6.10 range depend on a
  `macros` package version that requires a `_macros` package bundled only
  in certain Dart SDK builds, not present on a plain stable SDK. Fixed by
  pinning `analyzer: ^7.0.0` and `custom_lint_builder`/`custom_lint_core`:
  `^0.7.0` (confirmed against the real pub.dev version history), which
  resolves to `custom_lint_core` 0.7.1+ and does not touch that broken
  `macros`/`_macros` chain. `example/pubspec.yaml`'s `custom_lint`
  dependency was updated to match.
- Still not verified in this environment (no local Dart/Flutter SDK): a
  full `pub get` + `dart analyze` + `dart test` run across the root
  package, `test/fixtures/*`, and `example/`. The `test` package was also
  pinned to `>=1.24.0 <1.26.0` after an editor auto-upgrade briefly pulled
  in a `test` version requiring Dart SDK `>=3.10.0`, which was newer than
  the SDK actually installed (3.9.2) — re-check this cap once a maintainer
  can run `pub get` locally and confirm the newest `test` version their
  SDK actually supports.

## Infrastructure follow-ups

- **Plugin wiring smoke test.** `test/all_observer_lint_test.dart` only
  checks `createPlugin()` returns a `PluginBase`. A fuller test that
  constructs a real `CustomLintConfigs` and asserts every preset-referenced
  rule name is actually registered needs a maintainer with the
  `custom_lint` toolchain installed to confirm the exact `CustomLintConfigs`
  construction API for the pinned `custom_lint_builder` version — this
  could not be verified in the environment this package was authored in
  (no Dart/Flutter SDK available to run `pub get`/`dart test`).
- **Real `all_observer` verification.** Every library URI, class name, and
  extension name this package keys on (`AllObserverTypeChecker`) is
  transcribed from this project's own brief, not verified against the
  actual published `all_observer` source (network access to fetch it was
  not available while authoring this package — see
  `documentation/false_positives.md`). Before the first real-world
  integration (section 34 of the brief: validation against the
  `all_observer` repo, the example app, and a real consumer project), a
  maintainer should diff `AllObserverTypeChecker`'s constant names against
  the actual `all_observer` public API and adjust if anything drifted.
- **CI matrix.** `.github/workflows/ci.yml` currently pins one Dart/Flutter
  version. Expanding to a matrix (minimum supported + stable) is
  straightforward once the minimum supported analyzer/custom_lint_builder
  versions are confirmed against a real `pub get`.

## Future rules (not yet designed)

- `avoid_large_observer_scope` (performance; mentioned as an example in
  the brief's severity matrix, not designed in this version).
- Reactive-collection-specific rules once the actual `all_observer`
  collection API is available to key checks on.
