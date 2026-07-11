# avoid_observable_write_during_observer_build

- **Category:** reactive-cycle
- **Severity:** warning (candidate for a split `error` variant, not yet promoted — see below)
- **Blocking:** no
- **Preset:** `recommended`, `all`
- **Quick fix:** no
- **Applies to `all_observer`:** all versions where `Observer`'s callback re-runs on notification

## What it does

Flags a direct reactive write — `x.value = ...`, `x.value++`/`--`, or a
compound assignment on `.value` — inside an `Observer(...)` rendering
callback.

## Why

`Observer`'s callback is meant to be a read-only rendering function. A
write inside it, especially to a dependency the same callback reads, risks
an immediate re-render loop.

## Why not (yet) split into a stricter `error` rule

Per this project's evidence policy, only a write that is *proven* to cycle
deterministically — e.g. an unconditional write to a dependency the same
callback unconditionally reads — could become a stricter, `error`-level
`unconditional_reactive_write_during_observer_build` diagnostic. A
conditional write, or a write to an observable the callback does not
itself read, is architecturally questionable but not proven to crash in
every `all_observer` version. Bundling every case into one `error` rule
would violate the "blocking rules require proof" policy in this project's
brief (section 26.3). See `documentation/backlog.md`.

## Incorrect code

```dart
Observer(() {
  if (counter.value < 0) {
    counter.value = 0;
  }
  return Text('${counter.value}');
});
```

```dart
Observer(() {
  counter.value++;
  return Text('${counter.value}');
});
```

## Correct code

```dart
Observer(() => Text('${counter.value}'));

// Clamp counter where it's produced instead:
void increment() => counter.value = (counter.value + 1).clamp(0, 100);
```

## Exceptions

A write inside a nested closure that is not itself the `Observer` callback
(e.g. a button's `onPressed` declared inside the `Observer`'s returned
widget tree) is not flagged — it only runs on interaction, not while
`Observer` is building.

## Limitations

Writes to reactive collections are not detected in this version; only
`.value` assignment/increment/decrement.

## Disabling

```yaml
custom_lint:
  rules:
    - avoid_observable_write_during_observer_build: false
```

## Evidence

Severity is `warning`; no blocking claim, no evidence document required at
this severity. See `documentation/backlog.md` for the promotion path for a
future, narrower `error` variant.
