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

## `Wrap with Observer`: permissive by design

`lib/src/assists/wrap_with_observer_assist.dart` offers wrapping *any*
expression that resolves to a Flutter `Widget` with `Observer(() => ...)`,
regardless of whether a reactive read is present, whether `watch(context)`
is used, or whether the Widget sits inside a `build` method or some other
rebuild scope. This is a deliberate product decision, not an oversight: the
developer decides where an `Observer` boundary belongs; the plugin's job is
to make that mechanical edit safe and available everywhere it is
syntactically valid, not to gate it behind a guess about whether the
resulting `Observer` will "do anything."

Judging whether a given `Observer` usage was a good idea after the fact is
left entirely to the two opt-in lints:

- `observer_without_reactive_read` (opt-in via `strict.yaml`/`all.yaml`)
- `unobserved_reactive_read_in_build` (opt-in via `strict.yaml`/`all.yaml`)

Both stay opt-in — **not** part of `recommended.yaml`, and this task did not
change that — because a reactive read can be legitimately hidden behind a
helper method, a controller method, an inherited method, an external
abstraction, a builder, a closure, or some other component that itself
performs the read. Those are false positives for a rule that tries to prove
"no read happened," but they are not false *un*availabilities for the
assist, since the assist never tried to prove that in the first place.

The assist only checks the conditions required to produce valid,
non-redundant code:

1. the selected node's resolved static type is a Flutter `Widget`;
2. it is the smallest such Widget expression containing the
   cursor/selection (a bounded AST-path descent, see
   `_isSmallestWidgetContainingSelection` — it only recurses into children
   that themselves fully contain the selection, never a full subtree scan);
3. the node is not in a constant context (no automatic `const`-chain
   rewrite is attempted — see `documentation/backlog.md`);
4. `AllObserverImportResolver` can produce a safe import plan (this is
   unconditional: it always can, falling back to a uniquely prefixed import
   when needed);
5. the node is not already exactly the root expression an enclosing
   `Observer(...)` builder returns (`_isAlreadyObserverBuilderRoot` —
   arrow body or a top-level `return` in a block body; Widgets nested
   *inside* that root, e.g. a `Column`'s children, remain wrappable, since
   splitting one `Observer` scope into smaller ones is a legitimate
   performance decision);
6. the node is not itself an `Observer` creation (checked semantically via
   `AllObserverTypeChecker.isObserverWidgetCreation`, never by comparing
   identifier text).

`lib/src/utils/observer_wrap_edit_builder.dart` (`ObserverWrapEditBuilder`)
factors the "build the replacement text + import edit" step into a small,
independently testable unit; all import-safety logic (shadowing,
collisions, prefixed vs. unprefixed, ambiguous imports) still lives
entirely in `AllObserverImportResolver` — the assist and the edit builder
never reimplement it.

## Performance: per-execution caching and indices

`AllObserverTypeChecker` (`lib/src/utils/all_observer_type_checker.dart`) is
constructed once per rule/assist execution (a local variable inside each
`run()`/`DartAssist.run()`, never `static`/global) and memoizes the
supertype/interface/mixin hierarchy walk per `InterfaceElement` identity. A
single traversal per root element collects every `all_observer` and Flutter
framework name in that hierarchy at once, so `isObservableType`,
`isComputedType`, `isObservableListType`, `isObservableMapType`,
`isObservableSetType`, and `isFlutterWidgetType` (and friends) share one
walk instead of each re-walking the same chain. Because the cache is an
instance field scoped to one checker instance, and one checker exists per
execution, nothing here is shared across files, across rules, or across
analysis sessions — it cannot grow unbounded and never keeps analyzer
elements alive past the execution that created them.

Two rules that previously re-traversed a whole compilation unit / whole
`dispose()` call graph once per candidate now build a small index once and
query it in O(1) per candidate instead:

- `unused_reactive_state` builds a `ReactiveReferenceIndex`
  (`lib/src/utils/reactive_reference_index.dart`) once per
  `CompilationUnit` (cached in a local `Map<CompilationUnit,
  ReactiveReferenceIndex>.identity()` for the lifetime of that rule
  execution), so a file with N private reactive fields performs a constant
  number of full-unit traversals, not N of them.
- `dispose_reactive_resources` builds a `DisposalIndex`
  (`lib/src/utils/disposal_index.dart`) once per class by walking
  `dispose()` and its same-class, zero-argument local helpers exactly once
  (with cycle protection), recording every disposal-shaped call found. Each
  of the class's candidate resources is then a single map lookup instead of
  a fresh walk of the same call graph.

See `benchmark/` for the harnesses used to validate these are asymptotic
improvements, not just constant-factor ones, and
`documentation/backlog.md` for what this task deliberately left out of
scope (e.g. a `RebuildScopeFinder` cache, gated behind the same benchmarks
showing it would matter).

## Categories

See `lib/src/diagnostics/diagnostic_category.dart` for the full enum and
per-category rationale.
