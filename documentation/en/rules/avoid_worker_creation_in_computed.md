# avoid_worker_creation_in_computed

- **Category:** purity / resource-management
- **Severity:** warning
- **Blocking:** no
- **Preset:** `recommended`, `all`
- **Quick fix:** no
- **Applies to `all_observer`:** all versions exposing `effect`, `ever`, `once`, `debounce`, `interval`

## What it does

Flags `effect(...)`, `ever(...)`, `once(...)`, `debounce(...)`, or
`interval(...)` registered inside a `Computed` derivation callback.

## Why

`Computed` can be recomputed multiple times — including speculatively by
the dependency tracker — so each recomputation would register a brand-new,
never-cleaned-up subscription.

## Incorrect code

```dart
late final withWorker = Computed(() {
  ever(counter, (value) {});
  return counter.value;
});
```

## Correct code

```dart
late final derived = Computed(() => counter.value * 2);

// Register the worker once, outside Computed:
late final _tracker = ever(counter, (value) {});
```

## Exceptions

None beyond the standard semantic matching (only `effect`/`ever`/`once`/
`debounce`/`interval` resolved to `all_observer` are considered).

## Limitations

Registration through a helper function called from within the `Computed`
callback is not detected in this version.

## Disabling

```yaml
custom_lint:
  rules:
    - avoid_worker_creation_in_computed: false
```

## Evidence

Severity is `warning`; no blocking claim, no evidence document required.
