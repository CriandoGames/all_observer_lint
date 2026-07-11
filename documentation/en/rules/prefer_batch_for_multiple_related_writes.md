# prefer_batch_for_multiple_related_writes

- **Category:** performance
- **Severity:** info
- **Blocking:** no
- **Preset:** `strict`, `all` (not in `recommended`)
- **Quick fix:** no
- **Applies to `all_observer`:** any version exposing `batch`
- **Status:** experimental

## What it does

Flags three or more consecutive plain assignments to `.value` on different
observables within the same block, not already wrapped in `batch(...)`.

## Why

`all_observer` already coalesces synchronous notifications on its own, so
this is not a correctness claim — it's a suggestion for the cases where
external/manual listeners (or code outside `all_observer`'s own batching)
could otherwise observe an inconsistent intermediate state partway through
a multi-field update.

## Incorrect code (candidate for batch)

```dart
void reset() {
  name.value = '';
  email.value = '';
  age.value = 0;
}
```

## Suggested code

```dart
void reset() {
  batch(() {
    name.value = '';
    email.value = '';
    age.value = 0;
  });
}
```

## Exceptions

Two consecutive writes are not flagged — the threshold is deliberately set
at three to avoid nudging every pair of related writes into `batch`.

## Limitations

This rule does not attempt to reason about whether any listener actually
observes an inconsistent intermediate state; it only counts consecutive
plain writes. It is not included in `recommended` because `all_observer`'s
own coalescing already covers the common case, and indiscriminate `batch`
suggestions were explicitly ruled out by this project's brief (section
8.2).

## Disabling

```yaml
all_observer:
  rules:
    - prefer_batch_for_multiple_related_writes: false
```

## Evidence

`info` severity; a suggestion, not a claim of a bug. No evidence document
required.
