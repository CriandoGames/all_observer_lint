# computed_without_reactive_read

## Purpose

Reports a `Computed` callback with no statically visible tracked dependency.

## Incorrect

```dart
Computed(() => 42);
```

## Correct

```dart
Computed(() => count.value * 2);
```

## Severity

`info`; enabled only in `strict` and `all`.

## Limitations and possible false positives

This is a local static estimate. Unresolved code, unsupported callback forms,
and helper calls that may hide reads are suppressed. Interprocedural analysis
is intentionally out of scope.

## When to ignore

Ignore for an intentionally constant derived API when retaining `Computed` is
important for a stable public type.

## Fix or assist

No automatic fix or assist is available.
