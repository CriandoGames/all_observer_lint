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

## Assisted migrations: diagnostic/transformation capability levels

The assisted-migrations phase (`ChangeNotifier`/`ValueNotifier`/redundant-
`Observable`/listener-to-`effect`-or-`ever`/`AsyncState`/`ReactiveScope`)
introduces a shared vocabulary for "should this candidate be surfaced, and
how strongly": `lib/src/utils/migration_safety_result.dart`
(`MigrationCapability`, `MigrationSafetyResult`). Three levels, cumulative
in capability:

- `rule` — only a diagnostic is safe; no transformation is offered.
- `assist` — a manually-triggered transformation can be offered.
- `quickFix` — the diagnostic carries enough proven information to also
  attach an automatic, local, compilable fix.

Every migration analyzer in this phase builds one `MigrationSafetyResult`
per candidate from its own evidence and never re-derives safety from
scattered booleans downstream; the corresponding rule/assist/fix only
consults `allowsRule`/`allowsAssist`/`allowsQuickFix`. A candidate with no
capability at all (`isSilent`) produces no diagnostic, no assist, and no
fix — matching the phase's "permanecer silencioso em caso de dúvida"
principle: silence is a first-class, tested outcome, not an omission.

## Shared migration infrastructure

Three more utilities exist purely to keep the (upcoming) migration
analyzers from each re-walking a whole `CompilationUnit`:

- `lib/src/utils/reactive_collection_operation_classifier.dart`
  (`ReactiveCollectionOperationClassifier`) — classifies a resolved
  operation on an `ObservableList`/`ObservableMap`/`ObservableSet`
  receiver as `read`, `mutation`, `replacement` (a wholesale
  `assign`/`assignAll`), or `unknown`. Every method-name set is grounded in
  the real, published `all_observer` source (see
  `documentation/backlog.md`, "Assisted-migrations phase — real-runtime
  audit notes"), not the phase's own illustrative brief, which assumed
  `assign`/`assignAll` also exist on `ObservableMap`/`ObservableSet` — they
  do not.
- `lib/src/utils/semantic_reference_index.dart` (`UnitSemanticIndex`) —
  generalizes `ReactiveReferenceIndex`: `declarations`/`references` are
  built eagerly (cheap, always needed), while `reactiveReads`/
  `reactiveMutations`/`listenerRegistrations`/`listenerRemovals` are each a
  `late final` field computed lazily, on first access — a migration
  analyzer that never asks about listeners never pays for a listener-call
  walk of the unit. Deliberately coarse-grained: it records *that* an
  occurrence exists somewhere in the unit, not *where* (inside a tracking
  scope or not) — that context-sensitive judgment stays with each
  analyzer, which walks up locally from the small, already-found
  occurrence node (bounded by AST depth) instead of re-scanning the file.
- `lib/src/utils/source_edit_plan.dart` (`SourceEditPlan`,
  `SourceTextEdit`) — generalizes `ObserverWrapEdit`'s single-replacement
  shape to migrations that touch more than one source range in the same
  file (e.g. a field declaration plus every read of it). Validates at
  construction that no two edits overlap.

`AllObserverTypeChecker` gained three purely additive methods for this
phase — `isChangeNotifierType`, `isValueNotifierType`,
`isFlutterListenableType` — resolved exactly like every other check in
that class (declaring library URI first, name second), so a local class
named `ChangeNotifier`/`ValueNotifier` is never matched. No existing
method's behavior changed.

## Assisted migrations — Etapa B: reactive-collection mutation coverage

`lib/src/utils/reactive_write_detector.dart` (`ReactiveWriteDetector`) now
detects reactive-collection mutations/replacements
(`ReactiveCollectionOperationClassifier`'s `mutation`/`replacement` kinds —
`list.add(...)`, `map['k'] = v`, `list.length = n`, `list.assignAll(...)`,
...) in addition to its original `.value` assignment/increment/decrement
detection. This is a pure coverage widening of an existing, tested
detector — its public `findIn` signature is unchanged — consumed
automatically by both call sites that already existed:
`avoid_reactive_write_in_computed` and
`avoid_observable_write_during_observer_build` (both `recommended`,
`warning`). Every existing fixture for both rules was re-checked against
the real `all_observer` collection shape before this change to confirm
none contained a collection mutation that would newly flip from silent to
flagged (see `documentation/backlog.md`); new fixtures
(`computed_purity_collection_{invalid,valid}.dart`,
`observer_write_collection_{invalid,valid}.dart`) cover the new detection
paths directly. `prefer_batch_for_multiple_related_writes` was
deliberately **not** widened in this same change — see
`documentation/backlog.md`.

`lib/src/rules/copied_reactive_collection_outside_tracking.dart` is a new,
`strict`/`all`-only, `info`-severity rule: it flags a local `.toList()`/
`.toSet()` snapshot of a reactive collection that is read inside an
`Observer`/`Computed`/`effect` tracking scope while the original collection
is not — the classic "the Observer tracks a plain snapshot, not the
reactive source" bug. It reuses `TrackingCallbackResolver` (already shared
by every rule that needs to find an `Observer`/`Computed`/`effect`
builder closure) and stays silent whenever the original collection cannot
be resolved to a simple, traceable reference — see the rule's own
documentation for its full safety-gate list. Diagnostic only: no assist or
quick fix ships with it yet.

## Assisted migrations — Etapa C: menor subárvore reativa (Widget)

`lib/src/assists/wrap_smallest_reactive_subtree_assist.dart`
(`WrapSmallestReactiveSubtreeAssist`) is a new assist, registered alongside
— not in place of — the existing, permissive `Wrap with Observer` assist
(`wrap_with_observer_assist.dart`, itself unchanged). Both are always
offered together; they differ only in *what* they anchor on:

- The permissive assist ignores read content entirely: it wraps the
  smallest Widget containing the raw cursor/selection, regardless of
  whether anything reactive is read there.
- The specialized assist only activates when the selection is on (or
  inside) a resolved `.value` read of an `Observable`/`Computed`
  (`_ReactiveValueReadFinder`, a `RecursiveAstVisitor` that keeps the
  innermost matching read whose range contains the target). It then
  discards the raw selection and walks up from *that read* — not from the
  cursor — to find the Widget to wrap, so triggering it anywhere inside a
  read-bearing expression (not just exactly on it) still resolves to the
  same, correct anchor.

Both are offered at different priorities (permissive: `80`, specialized:
`79`) so neither shadows the other in the assist list.

**Upward walk and closure safety.** From the resolved read,
`_smallestSafeWidgetContaining` walks up the AST looking for the nearest
ancestor `Expression` whose static type is a Flutter `Widget`. If, before
finding one, the walk reaches a `FunctionExpression` whose own resolved
`FunctionType.returnType` is *not* a Flutter `Widget` (an event handler
such as `onPressed`/`onChanged`), the walk stops and the assist reports
unavailable (`null`) — a value read/write inside an event handler never
executes as part of any widget build, so an `Observer` wrapped around
something outside that handler would never see it. A closure whose return
type *is* a `Widget` (an `itemBuilder`, an `Observer`'s own builder,
`MaterialApp.builder`, ...) is transparent to the walk and does not block
it, since such closures run synchronously as part of some widget's build —
this is what lets the assist correctly wrap only the `Text` returned by a
`ListView.builder`'s `itemBuilder`, for a read of an indexed element.

**Reuse, not reimplementation.** The specialized assist reuses
`ObserverWrapEditBuilder` (replacement text and import-edit assembly) and
`AllObserverImportResolver` (all import-safety logic) exactly as the
permissive assist does — neither was touched. The small check for "is this
node already exactly the root of an enclosing `Observer(...)` builder"
(arrow body or block `return`) is deliberately **duplicated** from
`wrap_with_observer_assist.dart` rather than extracted into a shared
helper: the permissive assist is already tested and shipped, and extracting
a shared helper at this point would mean touching it for a feature that
does not need to. See `documentation/backlog.md` for the explicit
trade-off note.

**Scope (first version).** Only a `.value` read of
`Observable`/`Computed` is recognized as the anchoring read for the
*specialized* action. Reads of reactive collections
(`items.length`, `items.contains(...)`) and `watch(context)` are not yet
recognized triggers here — the permissive assist remains available
manually in those cases. See `documentation/backlog.md`, "Still deferred".

No rule, quick fix, or preset changed in this step — assist-only, matching
the phase's diagnostic/transformation separation.

## Categories

See `lib/src/diagnostics/diagnostic_category.dart` for the full enum and
per-category rationale.
