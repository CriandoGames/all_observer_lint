# Changelog

## Unreleased

Two independent changes, tracked together per the task brief. Not yet
released/published — see `documentation/backlog.md` for open follow-ups.

**`Wrap with Observer` is now permissive.** The assist no longer requires a
reactive read, a `watch(context)` call, or that the selection sit inside a
widget `build` method / other rebuild scope. It now appears over any
expression whose resolved static type is a Flutter `Widget`, choosing the
smallest such Widget containing the cursor/selection, as long as: the
context is not `const`, the node is not already exactly the root of an
enclosing `Observer(...)` builder (arrow body or block `return`), and the
node is not itself an `Observer` creation. Whether wrapping a particular
Widget with `Observer` was a good idea is left entirely to the existing
opt-in lints, `observer_without_reactive_read` and
`unobserved_reactive_read_in_build` — **their preset placement is
unchanged**: both remain opt-in via `strict.yaml`/`all.yaml`, not part of
`recommended.yaml`, because a reactive read can still be legitimately
hidden behind a helper, a controller method, an inherited method, an
external abstraction, a builder, or a closure. See
`documentation/architecture.md`, "`Wrap with Observer`: permissive by
design".

New `lib/src/utils/observer_wrap_edit_builder.dart` (`ObserverWrapEditBuilder`)
factors out replacement-text/import-edit assembly from the assist; all
import-safety logic remains solely in `AllObserverImportResolver`
(unchanged behavior for every existing collision/shadowing/prefix case).

**Performance.** `AllObserverTypeChecker` now memoizes its
supertype/interface/mixin hierarchy walk per execution (one checker
instance per rule/assist run, never global/static), collecting every
`all_observer`/Flutter class name in a type's hierarchy in a single
traversal instead of one traversal per `is*Type` check.
`unused_reactive_state` and `dispose_reactive_resources` now each build a
small index once (per compilation unit, and per class, respectively)
instead of re-walking the whole unit / the whole `dispose()` call graph
once per candidate variable/resource — see `lib/src/utils/
reactive_reference_index.dart`, `lib/src/utils/disposal_index.dart`, and
`documentation/architecture.md`, "Performance: per-execution caching and
indices". `benchmark/` has the harnesses used to validate this; run them
before/after on the same machine to reproduce (this task does not assert
specific millisecond numbers, since shared CI runners vary — see
`documentation/backlog.md`).

No preset composition changed, no rule was promoted or newly added, and no
`const` is ever removed automatically.

**Assisted-migrations phase, Etapa A (infrastructure only — no new rules,
assists, quick fixes, or preset changes yet).** Internal groundwork for the
upcoming `ChangeNotifier`/`ValueNotifier`/`Observable`-to-plain-value/
listener-to-`effect`-or-`ever`/`AsyncState`/`ReactiveScope` assisted
migrations (see `documentation/backlog.md`, "Still deferred"):

- `lib/src/utils/reactive_collection_operation_classifier.dart`
  (`ReactiveCollectionOperationClassifier`) — classifies a resolved
  `ObservableList`/`ObservableMap`/`ObservableSet` operation as `read`,
  `mutation`, `replacement`, or `unknown`. Every method-name set was
  re-verified directly against the real, published `all_observer` source
  (pinned `1.5.6`) while building this — see "Real-runtime corrections"
  below.
- `lib/src/utils/migration_safety_result.dart` (`MigrationSafetyResult`,
  `MigrationCapability`) — the shared three-level (`rule`/`assist`/
  `quickFix`) model every migration analyzer in this phase will use to
  decide how strongly (if at all) to surface a candidate, per the phase's
  "separar diagnóstico de transformação" / "permanecer silencioso em caso
  de dúvida" principles.
- `lib/src/utils/source_edit_plan.dart` (`SourceEditPlan`, `SourceTextEdit`)
  — generalizes `ObserverWrapEdit`'s single-replacement shape to plans that
  touch more than one source range of the same file, with built-in overlap
  validation.
- `lib/src/utils/semantic_reference_index.dart` (`UnitSemanticIndex`) —
  generalizes `ReactiveReferenceIndex` (full occurrence lists instead of a
  referenced/not-referenced boolean) and adds lazily-built, per-unit
  `reactiveReads`/`reactiveMutations`/`listenerRegistrations`/
  `listenerRemovals` maps, so later migration analyzers do not each run
  their own full-unit traversal.
- `AllObserverTypeChecker` gained `isChangeNotifierType`,
  `isValueNotifierType` and `isFlutterListenableType` (purely additive; no
  existing method changed) — resolved the same way as every other check in
  this class, through the element's declaring library URI, never by
  comparing an identifier's text.
- `benchmark/reactive_collections_benchmark.dart` and
  `benchmark/semantic_index_benchmark.dart` added, following the existing
  `benchmark/` conventions (`bench_stats.dart`, generated fixtures in
  `benchmark/fixtures/generators.dart`).

**Real-runtime corrections found while auditing `all_observer` 1.5.6 for
this phase** (see `documentation/backlog.md` for the full note):
`ObservableMap`/`ObservableSet` do **not** expose `assign`/`assignAll` —
only `ObservableList` does. `ObservableList` also exposes `addIf`,
`addAllIf` and `addIfNotNull`, not previously tracked by this package.

No preset changed, no rule was added or promoted, and no existing
rule/assist/fix behavior changed — this entry is internal infrastructure
only, added ahead of the migration analyzers/assists/rules that will
consume it in subsequent, separately-reviewed changes.

**Assisted-migrations phase, Etapa B (reactive collections).**

- `avoid_reactive_write_in_computed` and
  `avoid_observable_write_during_observer_build` (both `recommended`,
  `warning`) now also flag reactive-collection mutations/replacements
  (`list.add(...)`, `map['k'] = v`, `list.length = n`,
  `list.assignAll(...)`, ...), not only `.value` writes — a coverage
  widening of the shared `ReactiveWriteDetector`, whose public API is
  unchanged. Every existing fixture for both rules was re-verified to
  contain no collection mutation that would newly change behavior; new
  fixtures cover the widened detection directly. See
  `documentation/architecture.md` and `documentation/backlog.md`.
- New rule `copied_reactive_collection_outside_tracking` (`strict`/`all`,
  `info`, experimental, **not** in `recommended`): flags a local
  `.toList()`/`.toSet()` snapshot of a reactive collection read inside an
  `Observer`/`Computed`/`effect` tracking scope while the original
  collection itself is not read there — the Observer/Computed/effect
  tracks a plain snapshot and never updates when the source collection
  changes. Diagnostic only; no assist/quick fix yet. See
  `documentation/en/rules/copied_reactive_collection_outside_tracking.md`.

`prefer_batch_for_multiple_related_writes` was deliberately not widened in
this change (tracked in `documentation/backlog.md`). No other preset
changed; `recommended.yaml` gained no new rule.

**Bug fix (found by the full regression run, Etapa C checkpoint):**
`copied_reactive_collection_outside_tracking`'s
`_findReactiveCollectionInChain` did not walk through a `PrefixedIdentifier`
(a bare `target.property` where both sides are simple names, e.g.
`counters.keys` — syntactically distinct from `PropertyAccess`, which the
walk already handled), so a snapshot derived through one extra hop like
`counters.keys.toList()` was silently never traced back to the reactive
`ObservableMap` and never flagged. Fixed by adding the same
`PrefixedIdentifier` branch `_originalCollectionElement` already had.
Covered by the existing `MapKeysWidget` case in
`copied_reactive_collection_outside_tracking_invalid.dart` (already present,
was passing for the wrong reason — the assertion only checked the total
count, not which classes matched).

**Assisted-migrations phase, Etapa C (menor subárvore reativa — Widget).**

- New assist `WrapSmallestReactiveSubtreeAssist`
  (`lib/src/assists/wrap_smallest_reactive_subtree_assist.dart`), registered
  alongside (not replacing) the existing, now-permissive `Wrap with
  Observer` assist. Where the permissive assist offers to wrap whatever
  Widget contains the raw cursor/selection, this specialized action only
  activates when the selection is on (or inside) a resolved `.value` read
  of an `Observable`/`Computed`, and anchors on *that read* — walking up to
  the nearest ancestor expression whose static type is a Flutter `Widget`
  and wrapping only that, leaving surrounding siblings/containers (e.g. a
  `Column` around the matched `Text`) untouched. Offered at priority `79`,
  just under the permissive assist's `80`, so both can be available at once
  without either shadowing the other.
- Closure safety: the upward walk stops and the assist stays unavailable if
  it would have to cross a closure whose own resolved function type does
  not return a Flutter `Widget` (an event handler like `onPressed`) before
  ever reaching a Widget — a write/read inside an event handler never runs
  as part of a build, so an `Observer` inserted outside it would not track
  anything meaningful. Closures that *do* return a `Widget`
  (`itemBuilder`, an `Observer` builder, `MaterialApp.builder`, ...) are
  transparent to the walk, since they run synchronously as part of some
  widget's build.
- Reuses the existing `ObserverWrapEditBuilder` (replacement text/import
  edit assembly) and `AllObserverImportResolver` (import safety) unchanged.
  The small "is this node already exactly the root of an enclosing
  `Observer(...)` builder" check is deliberately duplicated from
  `wrap_with_observer_assist.dart` rather than extracted into a shared
  helper, to avoid touching that already-tested assist for this addition —
  see `documentation/backlog.md`.
- Scope (first version): only a `.value` read of `Observable`/`Computed` is
  recognized as the anchoring read. Reactive-collection reads
  (`items.length`, `items.contains(...)`) and `watch(context)` are not yet
  supported as triggers for this *specialized* action — the permissive
  assist remains available for those. See `documentation/backlog.md`.
- No rule, quick fix, or preset changed by this entry — assist-only, per
  the phase's diagnostic/transformation separation.

**Bug fix (found by the full regression run, Etapa D checkpoint):** a
pre-existing test in `test/all_observer_lint_test.dart` still asserted
`getAssists()` had length `1`, left over from before
`WrapSmallestReactiveSubtreeAssist` was registered in Etapa C. Updated to
assert both assists are present by type; no production code was at fault.

**Assisted-migrations phase, Etapa D (extract reactive expression to
Computed).**

- New assist `ExtractReactiveExpressionToComputedAssist`
  (`lib/src/assists/extract_to_computed_assist.dart`): on a selection that
  reads two or more *distinct* reactive values (e.g. `price.value *
  quantity.value`), extracts the smallest such expression to a `late final
  <name> = Computed(() => <expression>)` field and replaces the selection
  with `<name>.value`. Registered alongside the other two Widget-wrap
  assists, never replacing them.
- Deliberately the narrowest safe slice of the brief's Part 9, per
  "permanecer silencioso em caso de dúvida": the candidate must contain no
  assignment, `++`/`--`, `await`, nested closure, reactive-resource
  creation, or **any method call at all** (the most conservative possible
  reading of "no impure call" — general call purity is undecidable from
  syntax alone); every identifier in it must resolve to an instance field
  or top-level declaration, never a local variable, a parameter,
  `BuildContext`, or a `State`'s `widget` accessor; and the enclosing class
  must declare its own `dispose()` with a directly-visible
  `super.dispose();` (where `<name>.close()` is inserted) — required for
  correctness, not just convenience, since only a `State` object is
  guaranteed to run a `late final` field's initializer exactly once (a
  `StatelessWidget` field would be silently recreated every rebuild). See
  `documentation/architecture.md` for the full gate-by-gate rationale and
  `documentation/backlog.md` for what is explicitly deferred (repeated-
  expression triggering, a `dart:core` call allow-list, `widget.`-dependent
  insertion via `initState()`, skipping `close()` inside an existing
  `ReactiveScope.run()`, and evidence-based naming).
- Naming always falls back to the brief's own documented default —
  `computedValue`, `computedValue2`, ... — never a name guessed from the
  expression's shape.
- New `lib/src/utils/all_observer_symbol_import_resolver.dart`
  (`AllObserverSymbolImportResolver`) generalizes
  `AllObserverImportResolver`'s collision/shadowing/prefix-fallback logic
  to any `all_observer` top-level symbol (not just `Observer`), as a new,
  separate file — the existing, already-tested `Observer`-specific
  resolver is untouched. Intended for reuse by the remaining migration
  assists (Etapas E–H).
- No rule or quick fix ships with this — assist-only — and no preset
  changed.

**Assisted-migrations phase, Etapa E (convert `ValueNotifier` to
`Observable`).**

- New `lib/src/migrations/value_notifier_migration_analyzer.dart`
  (`ValueNotifierMigrationAnalyzer`) and `lib/src/assists/
  convert_value_notifier_assist.dart` (`ConvertValueNotifierAssist`) — the
  first migration to use the analyzer/assist split the brief itself
  suggested (Etapas C/D were simple enough not to need it), and the first
  to consume `MigrationSafetyResult` (built in Etapa A).
- Converts a **private** field/top-level `final ValueNotifier<T> x =
  ValueNotifier(v);` (or an inferred-type equivalent) to `Observable<T>`/
  `Observable`, rewrites every `.dispose()` call on it to `.close()`, and
  leaves `.value` reads/writes and any `addListener`/`removeListener` call
  completely untouched.
- **Listener calls need no rewrite at all** — confirmed, not assumed, by
  reading the real `all_observer` source directly:
  `Observable<T> implements ValueListenable<T>`, and its
  `addListener`/`removeListener` delegate to a plain listener registry
  exactly like Flutter's own `ValueNotifier`, never invoking the callback
  immediately. This makes leaving those calls untouched the fully
  behavior-preserving choice, not a shortcut. See
  `documentation/architecture.md`.
- Stays silent unless: the initializer is a *direct* `ValueNotifier(...)`
  construction; every other occurrence of the field is a `.value`
  read/write, a `.dispose()` call, or an `addListener`/`removeListener`
  call directly on it (this single check covers both a
  `ValueListenableBuilder`-style consumer and "an unknown API" from the
  brief's list, without special-casing either); and any
  `addListener`/`removeListener` usage is a single balanced pair. See
  `documentation/backlog.md` for what remains deferred (local-variable
  declarations, an explanatory diagnostic for unavailability, batch
  conversion) and a staging note on Parts 3/4 of the brief, which are not
  assigned to any lettered Etapa.
- No rule or quick fix ships with this — assist-only — and no preset
  changed.

**Assisted-migrations phase, Etapa F (convert a `ChangeNotifier` field to
`Observable` — first of four smaller Part 1 assists).**

- New `lib/src/migrations/change_notifier_migration_analyzer.dart`
  (`ChangeNotifierFieldMigrationAnalyzer`) and `lib/src/assists/
  convert_change_notifier_field_assist.dart`
  (`ConvertChangeNotifierFieldAssist`). The brief's own Part 1 explicitly
  asks for smaller, independent assists instead of one whole-class
  transform in the first version; only step 1 of its four
  (field+getter → `Observable`) is implemented here.
- Converts a **private** field + its matching, pure-passthrough getter
  (`int _count = 0; int get count => _count;`) on a class that **directly**
  extends Flutter's real `ChangeNotifier` into a single public
  `final count = Observable(0);` field, rewriting every occurrence of
  either the field or the getter to `.value` access. Every
  `notifyListeners()` call is left completely untouched, even when it
  becomes redundant for the field just converted — removing it safely is a
  separate, deferred step (2 of 4).
- Stays silent unless the enclosing class: is itself private; extends
  `ChangeNotifier` directly (not transitively); has no `with`/`implements`
  clause; does not override `addListener`/`removeListener`/`hasListeners`/
  `notifyListeners`; never tears off `notifyListeners` as a callback; never
  returns `this` as a `Listenable`-shaped value; and never passes `this`
  as an argument anywhere in its own body — all explicit blocking cases
  from the brief. The field itself must also have exactly one matching
  getter, no conflicting member, no occurrence of either symbol reaching
  outside the class, and no constructor-initializer-list assignment.
- Fixes a subtle correctness trap along the way: Dart's bare `$identifier`
  string-interpolation shorthand only ever captures a single identifier —
  naively replacing just the identifier's token range inside one would
  silently turn `'$score'` into `'$score.value'` (a literal `.value`
  suffix, never evaluated). The assist detects this shape and rewrites the
  whole interpolation node with explicit braces instead
  (`'${score.value}'`).
- **Bug fix (found by the full regression run, Etapa F checkpoint):**
  `UnitSemanticIndex.references` (`lib/src/utils/
  semantic_reference_index.dart`) silently missed a tracked field's
  occurrence whenever it was the direct target of a plain assignment or a
  compound assignment/increment/decrement (`_count = v`, `_count += v`,
  `_count++`) — analyzer does not populate a bare identifier's own
  `.element` in that shape; the resolution lives on the enclosing
  `AssignmentExpression`/`PostfixExpression`/`PrefixExpression`'s
  `writeElement`/`readElement` instead (all three implement
  `CompoundAssignmentExpression`). Every earlier tracked declaration
  (`Observable`/`Computed`/the reactive collections/`ValueNotifier`) is
  always accessed through `.value`/a method call, so this never surfaced
  before — `ChangeNotifier`'s plain field is the first tracked declaration
  ever written to directly. Left unfixed, `ConvertChangeNotifierFieldAssist`
  would rename the field's declaration while silently leaving a direct
  `_count++;` write untouched, producing code that no longer compiles.
  `_ReferenceCollector.visitSimpleIdentifier` now checks the enclosing
  compound-assignment expression's `writeElement`/`readElement` as a
  fallback whenever the identifier's own `.element` is null.
- See `documentation/backlog.md` for what remains deferred (removing a
  redundant `notifyListeners()`, removing `extends ChangeNotifier`,
  same-file public-class support, constructor-initializer-list fields,
  batch conversion).
- No rule or quick fix ships with this — assist-only — and no preset
  changed.

**Assisted-migrations phase, Etapa H (introduce `ReactiveScope` — final
scheduled migration).**

- New `lib/src/migrations/reactive_scope_introduction_analyzer.dart`
  (`ReactiveScopeIntroductionAnalyzer`) and `lib/src/assists/
  introduce_reactive_scope_assist.dart` (`IntroduceReactiveScopeAssist`).
  The first migration in this package to relocate code between two
  different syntactic positions (a field initializer moved into an
  `initState()` assignment) rather than only rewriting in place, since
  `ReactiveScope.run(fn)` only captures a `Computed`/`effect()`/`Worker`
  created *while it is executing* — confirmed directly against the real
  `all_observer` source.
- Consolidates **two or more** eligible fields (`Computed`, a `Worker`, or
  an `effect()`-backed `Disposer`) into a single `late final ReactiveScope
  _scope = ReactiveScope();`, moving each field's initializer into a
  `_scope.run(() { ... });` block inserted at `super.initState();`, deleting
  each field's own disposal call, and inserting `_scope.dispose();` at
  `super.dispose();`.
- **Not every disposable type qualifies** — `ObservableFuture`,
  `ObservableStream`, `ObservableHistory`, and `ObservableSubscription`
  share a disposal method name with a scope-eligible type but are never
  auto-captured by `ReactiveScope.run()` per its own class doc, so this
  analyzer always re-checks the field's actual type rather than inferring
  eligibility from the disposal method name alone.
- Stays silent unless the enclosing class: declares no explicit
  constructor; has its own `initState()`/`dispose()` with direct
  `super.initState();`/`super.dispose();` calls; has no existing `_scope`
  member; and at least two fields each have a direct, scope-auto-captured
  initializer, exactly one variable per declaration, a disposal statement
  found directly inside `dispose()`'s own block, and no *immediate*
  (non-lazy) cross-reference from a sibling field's initializer — a
  reference inside a closure (`Computed(() => total.value * 2)`) is safe
  and not flagged, since it only runs later, never during construction.
- See `documentation/backlog.md` for what remains deferred (multi-variable
  field declarations, manual `ObservableFuture`/`Stream`/`History`/
  `Subscription` registration, explicit-constructor classes,
  helper-delegated disposal, reusing an existing scope). Etapa G
  (`AsyncState`) remains explicitly deferred by its own scoping decision —
  also tracked there.
- **Bug fix (found by the full regression run, Etapa H checkpoint):**
  `_findDirectDisposalStatement` only recognized a disposal statement
  shaped as a `MethodInvocation`. A bare `disposeEffect();` call (invoking
  an `effect()`-backed `Disposer` field) can instead resolve as a
  `FunctionExpressionInvocation`, depending on whether the analyzer treats
  the callee as a method or as a callable value — `DisposalIndex` already
  handled both shapes, but this analyzer's own direct-block scan only
  checked one, so a class combining a `Computed` field with an `effect()`
  `Disposer` field found only one eligible field instead of two and the
  assist silently stayed unavailable. Fixed via a new
  `_isDirectInvokeCallbackOf` helper that checks both shapes, mirroring
  `DisposalIndex` exactly. The `Computed`+`Worker` and `Computed`+`Computed`
  combinations were unaffected.
- No rule or quick fix ships with this — assist-only — and no preset
  changed.

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
