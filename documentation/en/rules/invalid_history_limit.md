# invalid_history_limit

## Purpose

Warns when `ObservableHistory` receives a compile-time constant `limit` less
than or equal to zero. The runtime contract requires at least one entry.

## Incorrect

```dart
value.withHistory(limit: 0);
ObservableHistory(value, limit: -1);
```

## Correct

```dart
value.withHistory(limit: 1);
value.withHistory(limit: configuredLimit);
```

## Severity

`warning`; enabled in `recommended`, `strict`, and `all`.

## Limitations and possible false positives

Only resolved `all_observer` extension/constructor calls and known constants
are checked. Dynamic values are deliberately ignored, so false negatives are
possible. No known semantic false-positive shape is expected.

## When to ignore

Ignore only if a patched runtime intentionally accepts non-positive limits.

## Fix or assist

No automatic fix or assist is offered because the correct positive limit is a
domain decision.
