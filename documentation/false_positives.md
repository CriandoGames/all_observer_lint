# Known false-positive risk report

This is the "relatório de falsos positivos conhecidos" deliverable. It
lists every known way a rule in this version can produce a diagnostic that
is arguably not a real problem, and why the trade-off was accepted.

| Rule | Known false-positive shape | Why accepted |
|---|---|---|
| `avoid_reactive_write_in_computed`, `avoid_set_state_in_computed`, `avoid_worker_creation_in_computed`, `avoid_io_in_computed` | A closure nested inside `Computed` that only runs asynchronously/deferred (e.g. inside `Future(...).then(...)`) is still treated as part of the callback by `ComputedCallbackFinder`. | Rare in practice (deferred work inside a `Computed` derivation is itself unusual), and distinguishing sync-vs-deferred nested closures reliably from AST alone would require tracking whether the outer call is `Future`-returning across arbitrary APIs — out of scope for a first version. Tracked in `documentation/backlog.md`. |
| `avoid_observable_write_during_observer_build` | Same nested-async-closure caveat as above, scoped to `Observer` instead of `Computed`. | Same reasoning. |
| `dispose_reactive_resources` | A field disposed conditionally (e.g. only inside an `if (mounted)` block) inside `dispose()` is still recognized as disposed, even though a code path could skip it. Conversely, a field whose disposal is delegated to a helper method called from `dispose()` (`_disposeAll()`) is **not** recognized and produces a false positive. | The conditional-disposal case: treating any occurrence of `<field>.dispose()` in `dispose()` as sufficient is deliberately permissive, to avoid the opposite (and more costly) failure mode of demanding a single unconditional call. The helper-method case is a real, known gap — see `documentation/backlog.md` — accepted for v0.1 to keep the rule's AST walk simple and auditable; a project that always disposes through a shared helper should disable this rule (`dispose_reactive_resources: false`) until helper-method tracking ships. |
| `watch_only_inside_build` | A local/top-level function or closure calling `watch(context)` is treated as ambiguous and never flagged, even when it is provably wrong. | False negative, not false positive — listed here because it is the direct consequence of the same conservatism that avoids false positives elsewhere in this rule. The rule's explicit design goal (per the project brief) is "se não for possível determinar o contexto com segurança, não gerar diagnóstico." |
| `prefer_computed_for_derived_state` | Any observable that is *currently* purely derived, but is expected to grow independent state soon, is flagged as if the manual assignment were already a mistake. | Inherent to a static, syntactic heuristic; this is exactly why the rule is `info`, experimental, and excluded from `recommended`. |
| `prefer_batch_for_multiple_related_writes` | Three consecutive unrelated writes (not logically "related", just adjacent in source) can be flagged. | The rule does not attempt semantic "relatedness" analysis; `info` severity and exclusion from `recommended` reflect that limitation explicitly. |
| All rules keyed on `all_observer`'s exact library/class/extension names | If the real, published `all_observer` package structures its libraries differently than transcribed in `AllObserverTypeChecker` (this was authored from the project brief's description, not a verified read of the actual source — see `documentation/backlog.md`, "Real `all_observer` verification"), some or all rules could under-match (false negatives) until corrected. | Documented explicitly as a pre-release verification step; not a design flaw but an environment limitation while authoring this package. |

## Structural false-positive prevention (working as intended, listed for clarity)

These are **not** false positives; they are the specific defenses this
package puts in place and are tested in `test/fixtures/consumer/lib/*_valid.dart`:

- Symbols named identically to `all_observer` types but declared in a
  different package are never matched (see
  `test/fixtures/another_package`).
- A reactive resource created inside a nested closure that is not itself a
  rebuild/computed scope (e.g. a button's `onPressed`, or `dispose_reactive_resources`'s "no owning `dispose()`, stay silent") is not flagged.
- A field named `value` on an unrelated, non-reactive type is never
  confused with `.value` on `Observable`/`Computed` (matching requires the
  target's *static type*, not just the property name).
