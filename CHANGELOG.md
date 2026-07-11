# Changelog

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
  all_observer:
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
