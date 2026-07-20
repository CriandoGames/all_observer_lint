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

## Assisted migrations — Etapa D: extract reactive expression to Computed

`lib/src/assists/extract_to_computed_assist.dart`
(`ExtractReactiveExpressionToComputedAssist`) offers, on a selection that
reads two or more distinct reactive values, to extract that expression to
a `late final <name> = Computed(() => <expression>)` field and replace the
selection with `<name>.value`. It is registered alongside the other two
Widget-wrap assists, never replacing them.

**Candidate search.** `_CandidateFinder` uses
`GeneralizingAstVisitor.visitExpression` (not `RecursiveAstVisitor`,
because a qualifying candidate can be *any* expression shape —
`BinaryExpression`, `StringInterpolation`, a `ConditionalExpression`, ...
— unlike `WrapSmallestReactiveSubtreeAssist`'s search, which only ever
looks for one specific `.value`-access shape) to examine every expression
containing the selection and picks the smallest one that both reads two or
more *distinct* `.value` targets and passes every gate below. This is why
`price.value * quantity.value` inside `Text('${price.value *
quantity.value}')` extracts just the multiplication, while `'${first.value}
${last.value}'` (two reads, each alone in its own interpolation section)
extracts the whole string — nothing smaller than the full interpolation
has two distinct reads in that second case.

**Every gate below runs as a single pass (`_ImpurityCollector`) so that a
disqualifying construct anywhere in the candidate's subtree is caught
regardless of nesting.** The assist requires, all at once:

- **Purity** — no assignment; no `++`/`--`; no `await`; no nested
  `FunctionExpression`; no reactive-resource creation (`Observable`/
  `Computed`/the reactive collections/`ObservableFuture`/
  `ObservableStream`/`ReactiveScope`, or a `.obs` access); and, most
  conservatively, **no method call of any kind**. General call purity is
  undecidable from syntax alone; this package's policy is silence over a
  risky guess, so v1 simply disallows every `MethodInvocation` rather than
  trying to curate a safe subset. See `documentation/backlog.md` for the
  planned loosening (a curated `dart:core` allow-list).
- **Locality** — every identifier in the candidate (reactive or not) must
  resolve to an instance field or a top-level declaration, never a local
  variable or parameter: a field-level `late final` cannot close over
  either. This is checked generically over every `SimpleIdentifier`
  (`element is LocalVariableElement || element is FormalParameterElement`),
  which also transparently covers the prefix of a `PrefixedIdentifier`
  (`count` in `count.value`) via the same recursive visit every other node
  here relies on — with one deliberate exception: a named-argument label
  (`x` in `Point(x: x.value)`) resolves to the *callee's* parameter, not a
  reference in the current scope, and is skipped (`node.parent is Label`).
  The same mechanism also blocks `BuildContext` (any identifier whose
  static type resolves to Flutter's `BuildContext`) and `widget` (a
  `State`'s accessor for its `StatefulWidget`, resolved via its declaring
  library rather than by name alone) — supporting either would need an
  `initState()`-based insertion instead of a field initializer, which this
  version does not implement.
- **Owner lifecycle** — the enclosing class must declare its own
  `dispose()` with a directly-visible `super.dispose();` (the exact same
  shape `dispose_reactive_resources`/`AddDisposeCallFix` already require
  and insert before, duplicated here rather than shared — see
  `documentation/backlog.md`). This is a correctness requirement, not just
  a convenience: only a `State` object persists unchanged across rebuilds,
  so only there is a `late final` field guaranteed to run its initializer
  exactly once. A field added to a `StatelessWidget` — recreated on every
  rebuild — would silently reproduce the exact "recreated every rebuild"
  bug class `avoid_reactive_creation_in_build` exists to catch elsewhere in
  this package, which is why a missing `dispose()` (as on any
  `StatelessWidget`) leaves the assist unavailable rather than falling back
  to some other insertion point.

**Naming.** The brief asks for a derived name (`total`, `fullName`, ...)
"somente quando houver confiança". This package has no reliable way to
infer meaning from an arbitrary expression shape, so v1 always uses the
brief's own documented fallback — `computedValue`, or `computedValue2`,
`computedValue3`, ... the first name not already declared in the class —
rather than guess. Smarter naming is tracked in `documentation/backlog.md`.

**Import safety.** `lib/src/utils/all_observer_symbol_import_resolver.dart`
(`AllObserverSymbolImportResolver`) generalizes
`AllObserverImportResolver` (which stays hard-coded to `Observer` and is
deliberately left untouched — see `documentation/backlog.md`) to resolve
*any* `all_observer` top-level symbol the same way: reuse an existing
prefixed import, reuse an existing unprefixed import only if nothing
shadows it, or fall back to a freshly, uniquely prefixed import
(`allObserver.Computed`, `allObserver2.Computed`, ...). This is written to
be reused by the ChangeNotifier/ValueNotifier/AsyncState/ReactiveScope
assists in the remaining stages, all of which will need to reference other
`all_observer` symbols just as safely.

No rule or quick fix ships with this — assist only, per the phase's
diagnostic/transformation separation — and no preset changed.

## Assisted migrations — Etapa E: convert ValueNotifier to Observable

`lib/src/migrations/value_notifier_migration_analyzer.dart`
(`ValueNotifierMigrationAnalyzer`) and `lib/src/assists/
convert_value_notifier_assist.dart` (`ConvertValueNotifierAssist`)
implement the project brief's Part 2. This is the first migration to
follow the brief's own suggested split between an analyzer (pure
evaluation, producing a `MigrationSafetyResult`) and an assist (consumes
it, assembles edits) — Etapas C/D were simple enough not to need it.

**Why listener calls need no rewrite at all.** The brief assumes
`count.addListener(callback)` may need converting to an `effect`/`ever`
worker "só quando a semântica for equivalente". Checking the real,
published `all_observer` source directly (`lib/src/observable/
observable.dart`, `lib/src/core/core_observable.dart`) shows
`Observable<T> implements ValueListenable<T>`, and its `addListener`/
`removeListener` delegate straight to a plain listener registry — just
like Flutter's own `ValueNotifier`/`ChangeNotifier`: registration never
invokes the callback immediately, only a future value change does. Since
the semantics are already identical, this migration leaves every
`addListener`/`removeListener` call completely untouched — that **is**
the fully behavior-preserving choice here, not a shortcut. (A generic
listener-to-`effect`/`ever` conversion, Part 4 of the brief, remains a
useful, separate modernization someone could still want — it is simply
not *required* by this specific migration, and is not scheduled to its
own Etapa; see `documentation/backlog.md`.)

**Safety gates** (`ValueNotifierMigrationAnalyzer.evaluate`), all silent
on failure:

- the declaration must be a **private** field or top-level variable — only
  these are indexed by `UnitSemanticIndex.declarations`, so a public field
  is invisible to this migration entirely (a local variable is deferred
  too; see `documentation/backlog.md`);
- the initializer must be a direct `ValueNotifier(...)`/
  `ValueNotifier<T>(...)` construction — anything reached indirectly (a
  factory, a helper function, a cast) is not resolved;
- every occurrence of the field outside its own declaration (from
  `UnitSemanticIndex.references`) must classify as exactly one of: a
  `.value` read/write, a `.dispose()` call, or an `addListener`/
  `removeListener` call directly on the field. Anything else — passed as
  an argument (this one check alone covers both a `ValueListenableBuilder`-
  style consumer and "an unknown API", per the brief's own list, without
  needing to special-case either), assigned elsewhere, used as a bare
  `ValueListenable`/`Listenable` — is unrecognized and blocks the whole
  candidate;
- `addListener`/`removeListener` usage, if present at all, must be a
  single balanced pair — reusing `UnitSemanticIndex.listenerRegistrations`/
  `listenerRemovals`, which already only resolve a simple,
  directly-`Listenable`-typed, directly-referenced target (see that
  class's own doc).

**Edits.** Only three things are ever rewritten: the constructor call's
type name (`ValueNotifier` → `Observable`, done via the `NamedType.name`
token's own range so any generic type argument/nullability is preserved
byte-for-byte), the explicit declared type's name if one exists (same
technique — an inferred declaration, `final _flag = ValueNotifier(...)`,
is left inferred, matching the brief's "quando inferência for segura"
without needing to independently judge inference safety: whatever
explicitness the original code already chose is preserved), and each
`.dispose()` call's method name (`dispose` → `close`). `.value` and any
`addListener`/`removeListener` call are left byte-for-byte as written.
Reuses `AllObserverSymbolImportResolver` (Etapa D) for a safe `Observable`
reference — the file commonly has no `all_observer` import at all yet,
since `ValueNotifier` is pure Flutter.

No rule or quick fix ships with this — assist-only — and no preset
changed. The brief's "diagnosticar que existem consumidores
incompatíveis" (a companion diagnostic explaining *why* the assist is
unavailable) is deferred; every other assist in this package also stays
silently unavailable without one, so this is consistent with existing
precedent, not a new gap — see `documentation/backlog.md`.

## Assisted migrations — Etapa F: convert a ChangeNotifier field to Observable

`lib/src/migrations/change_notifier_migration_analyzer.dart`
(`ChangeNotifierFieldMigrationAnalyzer`) and `lib/src/assists/
convert_change_notifier_field_assist.dart`
(`ConvertChangeNotifierFieldAssist`) implement the *first* of the project
brief's four smaller Part 1 assists ("não transformar automaticamente a
classe inteira inicialmente"):

1. convert one private field + its getter to `Observable<T>` — this stage;
2. remove a redundant `notifyListeners()` call once every change in that
   method already notifies through `Observable` — deferred;
3. remove `extends ChangeNotifier` once nothing depends on it anymore —
   deferred;
4. add the `all_observer` import — folded into (1) via
   `AllObserverSymbolImportResolver`, same as Etapa D/E.

Every `notifyListeners()` call is left completely untouched by this stage,
even the ones that become redundant for the one field just converted —
proving a call is *safe to remove* needs whole-method reasoning ("every
change in this method already notifies via `Observable`") that is
deliberately out of scope here. Likewise `extends ChangeNotifier` stays in
the class; removing it needs proof that nothing still depends on the
class being a real `Listenable` (see below), which is its own, separate,
harder assist.

**Class-level gates** (`_classBlockReason`, checked once per candidate
field, all silent on failure) — the project brief's blocking list for
Part 1 is split here into what actually matters for *this specific*
field-level assist (the class keeps `extends ChangeNotifier` throughout,
so nothing about external `Listenable` consumers is broken by converting
one field) versus what is deferred to the future "remove the superclass"
assist. Even so, every one of the brief's class-shape conditions is
checked upfront, once, and shared by every future ChangeNotifier assist
added to this same file:

- the class itself must be **private** — proving "todas as referências
  necessárias estão no mesmo arquivo" for a *public* class would require
  seeing every other file in the package, which a single-file
  `custom_lint` pass cannot do; privacy is the one case this analyzer can
  actually prove;
- it must extend Flutter's real `ChangeNotifier` **directly** — checked on
  the class's own `extends` clause's resolved element, never via a
  transitive hierarchy walk, so a class extending some *other* class that
  itself extends `ChangeNotifier` further up is left alone;
- no `with` clause and no `implements` clause at all (a conservative
  reading of "não possui outra superclass relevante");
- no override of `addListener`, `removeListener`, `hasListeners`, or
  `notifyListeners`;
- `notifyListeners` is never torn off — every reference to it must be the
  direct target of a call; passing it as a bare callback
  (`api.addListener(notifyListeners)`) blocks the whole class, per the
  brief's explicit example;
- no getter/method returns `this` typed as `Listenable`-shaped
  (`Listenable get listenable => this;`), also per the brief's explicit
  example;
- `this` is never passed as an argument anywhere in the class's own body
  (covers `AnimatedBuilder(animation: this)`-style exposure written from
  inside one of its own methods — an *external* file passing some other
  variable of this type to `AnimatedBuilder` is the "used as Listenable"
  concern the future superclass-removal assist will need to prove instead,
  since converting one field never changes whether the class is still a
  `Listenable`).

**Field-level gates** (`_evaluateField`):

- private, non-static, non-`late` instance field with an initializer,
  whose declared type is not itself reactive or `Listenable`-shaped
  already (nothing to convert);
- exactly one getter named after the field (leading `_` stripped) exists,
  whose body is a pure passthrough (`=> _field;` or `{ return _field; }`)
  — no setter, method, or field sharing that derived public name;
- every occurrence of *both* the field's element and the getter's element
  anywhere in the compilation unit (a dedicated whole-unit
  `SimpleIdentifier` scan — `UnitSemanticIndex` only tracks *variable*
  declarations, never method/getter elements, so the getter's own
  occurrences need this separate pass) must fall inside the enclosing
  class's own source range. An occurrence reaching outside — another
  class in the same file reading the getter, say — stays silent rather
  than attempting a same-file, cross-class rewrite;
- the field must never be assigned through a constructor initializer list
  (`: _field = value`) — `Observable`'s `.value` setter cannot be the
  target of one, so this shape is left alone completely.

**Edits.** The field declaration and its getter are replaced as a unit:
`int _count = 0; int get count => _count;` becomes `final count =
Observable(0);`, and every occurrence of either symbol (bare `_count`
inside the class, or `count` reached through the getter) is rewritten to
`count.value`. The explicit `<T>` type argument on `Observable` is only
kept when relying on plain inference from the initializer would actually
narrow the type — e.g. `num _score = 0;` infers `Observable<int>` from
`0` alone, silently narrowing a field that used to accept `double` too, so
the explicit `<num>` is preserved there; when the declared and inferred
types already match (or there was no explicit annotation to begin with),
the bare inferred form is used, matching the brief's own example
(`final count = Observable(0);`, no generic). Reuses
`AllObserverSymbolImportResolver` (Etapa D/E) for a safe `Observable`
reference.

**A subtle correctness fix worth calling out**: Dart's bare `$identifier`
string-interpolation shorthand only ever captures a single identifier —
`'$score.value'` means `'${score}' '.value'`, with `.value` as *literal*
trailing text, not a property access. Naively replacing just the
identifier's own token range inside such a shorthand (`'$score'` →
`'$score.value'`) would silently print a literal `.value` suffix instead
of evaluating it. `_valueAccessEdit` detects this exact shape
(`InterpolationExpression` with `rightBracket == null`) and replaces the
*whole* interpolation node instead, adding explicit braces
(`'${score.value}'`) so the access is actually evaluated.

**A second, more structural fix found by the same regression run:**
`UnitSemanticIndex.references` (`lib/src/utils/semantic_reference_index.dart`)
was silently missing any occurrence where the tracked identifier is the
direct target of a plain assignment or a compound assignment/increment/
decrement (`_count = v`, `_count += v`, `_count++`). Analyzer does not
populate a bare identifier's own `.element` in that shape — the
resolution lives on the enclosing `AssignmentExpression`/
`PostfixExpression`/`PrefixExpression`'s `writeElement`/`readElement`
instead (all three implement `CompoundAssignmentExpression`). Every
tracked declaration before Etapa F (`Observable`/`Computed`/the reactive
collections/`ValueNotifier`) is always accessed through `.value`/a method
call, so the *tracked element itself* was never directly a compound-
assignment target before now — a `ChangeNotifier`'s plain field is.
Unfixed, the assist would rename the field's declaration while leaving a
direct `_count++;` write completely untouched, producing code that no
longer compiles — caught by the fixture's own `_CounterController` test,
not by manual review. `_ReferenceCollector.visitSimpleIdentifier` now
falls back to the enclosing compound-assignment expression's
`writeElement`/`readElement` whenever the identifier's own `.element` is
null. This is shared, non-migration-specific infrastructure, so it also
benefits the upcoming `AsyncState` migration (Etapa G), which tracks
plain boolean flag fields written the same direct way.

No rule or quick fix ships with this — assist-only, same
diagnostic/transformation separation as every prior stage — and no preset
changed.

## Assisted migrations — Etapa H: introduce ReactiveScope

`lib/src/migrations/reactive_scope_introduction_analyzer.dart`
(`ReactiveScopeIntroductionAnalyzer`) and `lib/src/assists/
introduce_reactive_scope_assist.dart` (`IntroduceReactiveScopeAssist`)
implement the project brief's Part 10 ("introdução segura de
`ReactiveScope`"), the last of the staged migrations. Etapa G (`AsyncState`)
was deferred by explicit decision — see `documentation/backlog.md`.

**Why this cannot be a small, local edit.** Every other assist in this
package rewrites code in place, at the position it already occupies.
`ReactiveScope.run(fn)` only captures a `Computed`/`effect()`/`Worker`
created *while it is executing* — confirmed by reading the real, published
`all_observer` source directly (`core_computed.dart`, `effects/effect.dart`,
`workers/workers.dart`): each of those three constructors calls
`ReactiveScope.current?.add(...)` internally. A field with an inline
initializer (`late final total = Computed(...);`) constructs its value as
part of the instance's *construction*, before any `run()` call could
possibly be active. Introducing a scope therefore genuinely requires moving
the initializer out of the field declaration and into an assignment
statement inside a `_scope.run(() { ... })` block placed in `initState()` —
the first migration in this package that relocates code between two
different syntactic positions rather than only rewriting in place.

**Not every disposable type is scope-eligible.** `ObservableFuture`,
`ObservableStream`, `ObservableHistory`, and `ObservableSubscription` all
share a disposal *method name* with a scope-eligible type
(`.close()`/`.dispose()`), but `ReactiveScope`'s own class doc is explicit
that none of them are auto-captured — they must be registered manually via
`scope.add(...)`. The analyzer never infers eligibility from
`ReactiveDisposalResolver`'s disposal *kind* alone; it always re-checks the
field's actual type (`Computed`, `Worker`, or a `Disposer` whose initializer
is proven to be a real `effect(...)` call).

**Analyzer result shape is deliberately richer than usual.**
`ReactiveScopeIntroductionResult` carries the ordered list of
`ReactiveScopeEligibleField`s (each with its `FieldDeclaration`,
`VariableDeclaration`, `ReactiveDisposalKind`, and the exact
`ExpressionStatement` to delete) alongside the usual `MigrationSafetyResult`
— unlike every earlier analyzer in this phase, which only returns the
safety verdict. Re-deriving the eligible-fields list a second time inside
the assist would mean re-running the same `DisposalIndex` walk and the same
direct-block statement scan twice, with a real risk of the two derivations
silently drifting apart; producing the list once and having the assist
consume it directly removes that risk.

**Class-level gates:**

- has its own `initState()` with a directly-visible `super.initState();`
  statement — the insertion point for the moved assignments;
- has its own `dispose()` with a directly-visible `super.dispose();`
  statement and a block body — mirrors the exact requirement
  `ExtractReactiveExpressionToComputedAssist` (Etapa D) already uses, for
  the same reason: only a persistent, lifecycle-managed object (not a
  `StatelessWidget`, recreated every rebuild) can safely own a scope;
- declares **no explicit constructor** — an explicit constructor body runs
  *before* `initState()`, so a field it (or another field's inline
  initializer) reads would now read an unassigned `late` field and throw.
  Rather than prove no such read exists, this narrows to the case where it
  structurally cannot happen: no custom constructor at all (the common case
  for a `State` subclass);
- has no existing member named `_scope` (the fixed name this assist always
  introduces).

**Field-level gates (all of the below, per candidate):**

- a private or public, non-static field with a **direct** inline initializer
  (an `InstanceCreationExpression`/`effect(...)`/worker-function call
  resolved back to `all_observer` — the same directly-owned check
  `dispose_reactive_resources` already applies, reused here);
- the field's type is scope-auto-captured: `Computed`, `Worker`, or a
  `Disposer`-typed field whose initializer is a real `effect(...)` call;
- exactly one variable per `FieldDeclaration` (`final a = ..., b = ...;`
  sharing one declaration is skipped rather than attempting a partial-list
  edit — see `documentation/backlog.md`);
- already disposed correctly, with the exact matching contract, by a
  statement **directly** inside `dispose()`'s own block — not through a
  local helper. `DisposalIndex` would still find a helper-delegated
  disposal, but this analyzer additionally requires the literal statement
  to edit be found directly, so a helper-delegated candidate is silently
  excluded rather than guessed at;
- never referenced *immediately* — outside any nested closure — from
  another field's initializer anywhere in the class. A reference inside a
  closure is different and deliberately not flagged:
  `late final doubled = Computed(() => total.value * 2);` never reads
  `total.value` at construction time, only whenever `doubled.value` is
  later evaluated, by which point `initState()` (and `total`'s new
  assignment inside it) has already run.
  `_ImmediateElementReferenceFinder` models exactly this by refusing to
  descend into any `FunctionExpression`. This refinement was caught during
  implementation, before any test run: a first draft would have incorrectly
  blocked this common, safe pattern.

At least **two** fields must pass every gate above — introducing a scope
for a single resource has no consolidation benefit and is not offered.

**Edits**, in order:

1. insert `late final ReactiveScope _scope = ReactiveScope();` right after
   the class's opening brace;
2. replace each eligible field's declaration with a bare
   `late final <type> <name>;` (the initializer is removed from here);
3. insert a `_scope.run(() { ... });` block at the `super.initState();`
   statement, assigning every eligible field, in original declaration
   order, to its original initializer expression;
4. delete each eligible field's own disposal statement from `dispose()`;
5. insert `_scope.dispose();` at the `super.dispose();` statement.

Reuses `AllObserverSymbolImportResolver` (Etapa D/E/F) for a safe
`ReactiveScope` reference. A defensive `_mergeSameOffsetEdits` step
collapses any two edits that land at the exact same offset (e.g. the
`_scope` field's zero-length insertion colliding with the first eligible
field's declaration replacement when there is no whitespace between `{`
and the first member) before handing the plan to `SourceEditPlan`, whose
overlap check assumes edits at distinct offsets.

**Bug fix (found by the regression run, Etapa H checkpoint):** the initial
`_findDirectDisposalStatement` only matched a candidate's disposal
statement when it parsed as a `MethodInvocation`. A bare, zero-argument
`disposeEffect();` call — invoking an `effect()`-backed `Disposer` field,
the `invokeCallback` disposal shape — does not always parse that way:
depending on whether the callee resolves to an actual method or to a
field/local variable of a callable type, the analyzer represents the exact
same call syntax as either a `MethodInvocation` (bare-identifier call
syntax always starts out this way at parse time) or a
`FunctionExpressionInvocation` (once resolution determines the callee is
a callable *value*, not a method — an implicit `.call()`). `DisposalIndex`
already handles both shapes (see its own
`visitFunctionExpressionInvocation` override), but this analyzer's
separate, direct-block-only scan only checked the first, so a class
combining a `Computed` field with an `effect()` `Disposer` field (the
`ComputedAndEffectWidget` fixture) silently found only one eligible field
instead of two, and the assist stayed unavailable rather than firing.
Fixed by adding `_isDirectInvokeCallbackOf`, which checks both AST shapes
for this one disposal kind, mirroring `DisposalIndex`'s existing handling
exactly. The `Computed`+`Worker` and `Computed`+`Computed` combinations
were unaffected, since `disposeMethod`/`closeMethod` disposal (an explicit
`.dispose()`/`.close()` call on a target) is always a `MethodInvocation`
and never hits this code path.

No rule or quick fix ships with this — assist-only, same
diagnostic/transformation separation as every prior stage — and no preset
changed.

## Categories

See `lib/src/diagnostics/diagnostic_category.dart` for the full enum and
per-category rationale.
