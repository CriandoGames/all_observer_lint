# effect_without_reactive_read

## Purpose

Reports an `effect` callback with no statically visible tracked reactive read,
meaning it has no dependency that can schedule another run.

## Incorrect

```dart
effect(() => log('started'));
```

## Correct

```dart
effect(() => log('${session.value}'));
```

## Severity

`info`; enabled only in `strict` and `all`.

## Limitations and possible false positives

This is a local static estimate. Unresolved code, unsupported callback forms,
and helper calls that could hide reads are suppressed. Indirect dependencies
are not followed across functions.

## When to ignore

Ignore when an intentionally one-shot callback must keep an `effect`-typed
lifecycle for external architectural reasons.

## Fix or assist

No automatic fix or assist is available.
