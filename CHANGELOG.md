# Changelog

## 0.1.0

Initial release. Foundation (Fase 1) and location/lifecycle rules
(Fase 2), plus purity rules (Fase 3) and experimental strict rules.

### Added

- `custom_lint` plugin infrastructure (`AllObserverLintPlugin`,
  `createPlugin()`).
- Centralized semantic identification layer (`AllObserverTypeChecker`) —
  no rule matches on identifier text alone.
- Bilingual diagnostics (English default, `pt-BR` opt-in via
  `all_observer: language: pt-BR`).
- `recommended.yaml`, `strict.yaml`, `all.yaml` presets.
- Rules (all in `recommended` unless noted):
  - `avoid_reactive_creation_in_build`
  - `avoid_effect_creation_in_build`
  - `watch_only_inside_build`
  - `dispose_reactive_resources` (with a quick fix)
  - `avoid_reactive_write_in_computed`
  - `avoid_set_state_in_computed`
  - `avoid_worker_creation_in_computed`
  - `avoid_io_in_computed`
  - `avoid_observable_write_during_observer_build`
  - `prefer_computed_for_derived_state` (`strict` only, `info`)
  - `prefer_batch_for_multiple_related_writes` (`strict` only, `info`)
- Bilingual per-rule documentation (`documentation/en/rules`,
  `documentation/pt-BR/rules`).
- `documentation/architecture.md`, `documentation/backlog.md`,
  `documentation/false_positives.md`.
- Local test fixtures (`test/fixtures/fake_all_observer`,
  `test/fixtures/another_package`, `test/fixtures/consumer`) and rule
  tests resolving them via `package:analyzer`'s
  `AnalysisContextCollection`.
- `example/` Flutter app demonstrating flagged/fixed pairs for the main
  rules.
- CI workflow (format, analyze, test, `pub publish --dry-run`).

### Notes

- `avoid_side_effects_in_computed`, originally planned as a single broad
  rule, was split before release into
  `avoid_reactive_write_in_computed`, `avoid_set_state_in_computed`,
  `avoid_worker_creation_in_computed`, and `avoid_io_in_computed` — see
  `documentation/backlog.md`, "Why not one avoid_side_effects_in_computed
  rule."
- No rule in this release is `error`-level. Every rule that touches a
  potential reactive-cycle concern documents, in its own file, the
  specific proof that would be required before a promotion — see
  `documentation/backlog.md`.
- This package was authored without access to the real, published
  `all_observer` source or a local Dart/Flutter SDK to run `pub get`/
  `dart test`/`dart analyze`. Library/class/extension names in
  `AllObserverTypeChecker` are transcribed from the project brief;
  verifying them against the real package, and running the full test/CI
  suite for the first time, is the first follow-up task for a maintainer
  with that access — see `documentation/backlog.md`.
