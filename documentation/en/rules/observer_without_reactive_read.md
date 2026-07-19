# observer_without_reactive_read

## Purpose

Reports an `Observer` builder with no statically visible tracked reactive read.

## Incorrect

```dart
Observer(() => const Text('Static'));
```

## Correct

```dart
Observer(() => Text('${count.value}'));
```

## Severity

`info`; enabled only in `strict` and `all`.

## Limitations and possible false positives

This is a local static estimate. Unsupported builder forms, unresolved code,
and helper calls that could hide a read are suppressed. Indirect reads through
advanced metaprogramming may still be missed.

## When to ignore

Ignore when tracking is intentionally supplied by behavior the local analyzer
cannot see, and document that ownership in code.

## Fix or assist

No fix. The separate `Wrap with Observer` assist is for untracked Widget
expressions that already contain a proven reactive read.
