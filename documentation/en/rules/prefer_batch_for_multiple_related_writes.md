# prefer_batch_for_multiple_related_writes

- **Category:** performance
- **Severity:** info
- **Blocking:** no
- **Preset:** `strict`, `all` (not in `recommended`)
- **Quick fix:** yes - wraps the consecutive writes in `Observable.batch`
- **Applies to `all_observer`:** any version exposing `Observable.batch`
- **Status:** experimental

## What it does

Flags three or more consecutive plain assignments to `.value` on different
observables within the same block, not already wrapped in
`Observable.batch(...)`.

## Why

`all_observer` already coalesces synchronous notifications on its own, so
this is not a correctness claim. It is a suggestion for the cases where
external/manual listeners, or code outside `all_observer`'s own batching,
could otherwise observe an inconsistent intermediate state partway through
a multi-field update.

## Incorrect code

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
  Observable.batch(() {
    name.value = '';
    email.value = '';
    age.value = 0;
  });
}
```

## Quick fix

The quick fix wraps the detected consecutive writes in `Observable.batch`.

## Exceptions

Two consecutive writes are not flagged. The threshold is deliberately set at
three to avoid nudging every pair of related writes into `Observable.batch`.

## Limitations

This rule does not attempt to reason about whether any listener actually
observes an inconsistent intermediate state; it only counts consecutive
plain writes. It is not included in `recommended` because `all_observer`'s
own coalescing already covers the common case, and indiscriminate
`Observable.batch` suggestions were explicitly ruled out by this project's
brief.

## Disabling

```yaml
custom_lint:
  rules:
    - prefer_batch_for_multiple_related_writes: false
```

## Evidence

`info` severity; a suggestion, not a claim of a bug. No evidence document
required.
