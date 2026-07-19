# Architecture

## Framework choice: `custom_lint`

`all_observer_lint` is built on [`custom_lint`](https://pub.dev/packages/custom_lint)
(`custom_lint_builder` for authoring, `custom_lint` for consumers), not a
bespoke analyzer plugin and not a standalone CLI.

Why:

- **Consolidated, actively used, IDE-integrated.** `custom_lint` is the de
  facto standard for third-party Dart/Flutter lint rules as of this
  writing (used by `riverpod_lint`, `bloc_lint`, and others referenced in
  this project's own brief). It surfaces diagnostics directly in the IDE
  via `dart analyze`/the analysis server, exactly the "orientação direto
  na IDE" requirement.
- **No custom CLI needed.** Consumers already have `dart analyze` /
  `flutter analyze` in their workflow; `custom_lint` plugs into that
  instead of requiring a new command, satisfying "não criar CLI própria
  nesta etapa."
- **Quick fixes for free.** `custom_lint_builder`'s `DartFix` API gives IDE
  quick-fix integration without reimplementing the LSP code-action
  plumbing.
- **Composable presets via `analysis_options.yaml`'s own `include:`
  mechanism.** `recommended.yaml` / `strict.yaml` / `all.yaml` are plain
  YAML files a consumer's `analysis_options.yaml` can `include:`, matching
  the ecosystem convention already used by `flutter_lints` and similar
  packages. Because this package runs on `custom_lint`, rule enablement and
  rule options live under `custom_lint.rules`, not under a bespoke top-level
  `all_observer:` parser.
- **Isolated analyzer dependency.** Only `lib/src/utils/`, `lib/src/rules/`,
  and `lib/src/fixes/` touch `package:analyzer` directly. If a future
  analyzer/custom_lint_builder major version changes its API (this
  ecosystem has had breaking `Element`/`Element2` migrations before), the
  blast radius is those directories, not the whole package — matching
  requirement #13 ("isolar dependências do analyzer").

We explicitly did **not**:

- Write a full `analyzer_plugin`-only integration from scratch (more
  boilerplate, worse IDE support today, and would duplicate what
  `custom_lint_builder` already solves).
- Copy `bloc_lint`'s infrastructure wholesale (per the brief's constraint);
  only the high-level idea of "use custom_lint" is shared with it, because
  that is the ecosystem-standard choice, not because code was copied.

## Why no Flutter dependency in the package itself

`all_observer` explicitly advertises a Flutter-independent reactive core
(`Observable`, `Computed`, workers, `batch` do not need Flutter). Rules
that only concern that core (e.g. a future `self_referencing_computed`)
must be usable by pure-Dart consumers. `all_observer_lint`'s own
`pubspec.yaml` therefore has **no** `flutter: sdk: flutter` dependency —
only `analyzer` and `custom_lint_builder`, both pure Dart.

Rules that are inherently about Flutter widget lifecycle
(`avoid_reactive_creation_in_build`, `watch_only_inside_build`, etc.) still
work without a Flutter *dependency* in this package: the analyzer resolves
symbols against whatever the **consumer's** project depends on. The rule
code only checks resolved element/library identity strings (e.g. does this
`BuildContext` parameter resolve to a class whose library URI starts with
`package:flutter/`) — see `AllObserverTypeChecker.isFlutterFrameworkElement`
— which works whether or not `all_observer_lint` itself imports Flutter
packages.

## Semantic identification layer

All symbol matching goes through `lib/src/utils/all_observer_type_checker.dart`
(`AllObserverTypeChecker`). No rule compares an identifier's text to a
string like `'Observable'` on its own. Every check:

1. resolves the relevant `Element`;
2. confirms the element's declaring library URI starts with
   `package:all_observer/`;
3. only then checks the simple name against a known-symbol list.

This is what keeps a class named `Observable` in an unrelated package (see
`test/fixtures/another_package`) from ever being flagged, and is
deliberately centralized so a future `all_observer` API addition requires
touching one file, not every rule.

Two more utilities build on top of the checker for cross-rule concerns:

- `build_context_detector.dart` (`RebuildScopeFinder`) — "is this AST node
  inside a widget `build` method or an `Observer` callback, without
  crossing an unrelated closure boundary" — shared by
  `avoid_reactive_creation_in_build`, `avoid_effect_creation_in_build`,
  `avoid_observable_write_during_observer_build`.
- `computed_callback_finder.dart` (`ComputedCallbackFinder`) — the
  equivalent for `Computed` callbacks — shared by the four purity rules.
- `reactive_write_detector.dart` (`ReactiveWriteDetector`) — finds direct
  `.value` writes/increments within a subtree — shared by
  `avoid_reactive_write_in_computed` and
  `avoid_observable_write_during_observer_build`.

## Localization

`lib/src/localization/` centralizes every diagnostic string behind a
`DiagnosticMessageKey` enum. Rules never inline text; they call
`DiagnosticMessages.forLocale(resolveLocale(configs)).message(key)`. See
`documentation/en/rules/*.md` and `documentation/pt-BR/rules/*.md` for the
localized documentation counterpart.

## Testing strategy

Full `custom_lint` integration tests (spinning up the actual plugin
process against a consumer project and asserting on `dart run custom_lint`
output) are the most faithful, but slow and heavy to set up. This version
instead:

1. Builds a local, `pub`-free fixture project
   (`test/fixtures/consumer`), depending only on
   `test/fixtures/fake_all_observer` (a minimal local stand-in for the
   real package) and `test/fixtures/another_package` (for homonym-symbol
   tests) — see requirement #10 ("criar fixtures locais").
2. Resolves fixture files with `package:analyzer`'s
   `AnalysisContextCollection` directly (`test/support/resolve_fixture.dart`).
3. Runs the exact same detector/utility classes the shipped rules call —
   `AllObserverTypeChecker`, `RebuildScopeFinder`, `ComputedCallbackFinder`,
   `ReactiveWriteDetector` — against the resolved AST, and asserts on the
   number/kind of matches.

This exercises the real semantic logic without depending on network access
or a full `custom_lint` runner in CI.

## Current semantic and transformation infrastructure

The current implementation also centralizes `ReactiveReadCollector`,
`ReactiveDisposalResolver`, `TrackingCallbackResolver`, and
`AllObserverImportResolver`. Together they keep deferred closures, tracking
escape hatches, disposal contracts, and import combinators consistent across
rules and assists.

New rules execute through `DartLintRule.testRun`. Transformation tests invoke
the real `DartFix`/`DartAssist`, apply full-file edits, format, resolve again,
verify the diagnostic disappears, and check idempotency. CI loads all rules and
assists through `dart run custom_lint` in `test/fixtures/smoke` and applies the
disposal fix to a temporary copied target, then re-formats, re-analyzes, and
re-runs `custom_lint` to prove the diagnostic is actually gone (not just that
some text was inserted).

`test/fixtures/smoke`, however, still resolves against
`test/fixtures/fake_all_observer` — this package's own local stand-in for
`all_observer`, never the published package. `test/fixtures/real_runtime_smoke`
closes that remaining gap: it is pinned to the real, published `all_observer`
package (`>=1.5.6 <1.6.0`) and runs the same analyze → lint → fix → re-lint
sequence in its own CI job, proving this package's rules and quick fixes
actually behave correctly against the real API — not only against a fake
whose shape could (and once did, before the 0.5.1 audit) silently drift from
reality. `test/runtime_contract/fake_runtime_contract_test.dart` guards that
fake's shape between real-package audits, with a lightweight, network-free
source check.

## Categories

See `lib/src/diagnostics/diagnostic_category.dart` for the full enum and
per-category rationale.
