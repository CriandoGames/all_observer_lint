# avoid_reactive_write_in_computed

- **Category:** purity
- **Severity:** warning (candidate for `error`, not yet promoted — see below)
- **Blocking:** no
- **Preset:** `recommended`, `all`
- **Quick fix:** no
- **Applies to `all_observer`:** all versions where `Computed` callbacks are re-invoked on dependency change

## What it does

Flags a direct write to a reactive value — `x.value = ...`, `x.value++`,
`x.value--`, or a compound assignment on `.value` — inside a `Computed`
derivation callback.

## Why

`Computed` must derive a value without side effects. A write inside it can
invalidate the very dependency graph being evaluated, and is unpredictable
under `all_observer`'s memoization/re-evaluation strategy.

## Why not `error` yet

Section 23 of this project's own contribution guide ("blocking rules
require proof") requires a reproducible failure demonstrated against the
`all_observer` engine itself, plus a runtime regression test in that
repository, before a rule can block CI by default. That evidence has not
been collected for every shape of write this rule detects (in particular,
whether all_observer's runtime intercepts the write, throws, or silently
produces a stale value depends on the exact write pattern — see
`documentation/backlog.md`, "observable_write_during_computed"). Until
then this stays a `warning`.

## Incorrect code

```dart
final normalized = Computed(() {
  if (name.value.isEmpty) {
    name.value = 'Unknown';
  }
  return name.value.trim();
});
```

## Correct code

```dart
final normalized = Computed(
  () => name.value.isEmpty ? 'Unknown' : name.value.trim(),
);
```

## Exceptions

- Pure, side-effect-free nested closures (`.map`, `.where`, `.fold`, and
  similar) are not flagged — only an actual write to `.value` is.
- A field named `value` on an unrelated (non-reactive) type is never
  confused with a reactive `.value` — matching requires the target's
  static type to be `Observable`/`Computed`.

## Limitations

- Writes to reactive collections (`list.add(...)`) are not detected in
  this version; only `.value` assignment/increment/decrement.
- A write inside a genuinely deferred nested closure (e.g.
  `Future(...).then((_) { x.value = 1; })`) is still flagged even though it
  does not run synchronously as part of the derivation — see
  `documentation/backlog.md`.

## Disabling

```yaml
all_observer:
  rules:
    - avoid_reactive_write_in_computed: false
```

## Evidence

No `error` claim is made; no `documentation/evidence/` entry required at
this severity. See `documentation/backlog.md` for the promotion path.
