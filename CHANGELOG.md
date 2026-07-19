# Changelog

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
