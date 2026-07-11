# avoid_set_state_in_computed

- **Category:** purity
- **Severity:** warning
- **Blocking:** no
- **Preset:** `recommended`, `all`
- **Quick fix:** no
- **Applies to `all_observer`:** any version, in combination with Flutter's `State.setState`

## What it does

Flags `setState(...)` called inside a `Computed` derivation callback.

## Why

`Computed` callbacks can run outside the widget lifecycle — for instance,
speculatively, during dependency tracking triggered by an unrelated
`Observer`. Calling `setState` from there touches widget state outside of
a build/event context, which Flutter itself does not guarantee is safe.

## Incorrect code

```dart
late final flag = Computed(() {
  setState(() {});
  return someObservable.value;
});
```

## Correct code

```dart
late final flag = Computed(() => someObservable.value);

// React to the change explicitly instead:
late final _sync = ever(someObservable, (_) => setState(() {}));
```

## Exceptions

Only `setState` resolved to Flutter's `State` class is flagged; a
same-named method on an unrelated class is not (matching is done on the
resolved element's library, not the method name alone).

## Limitations

`setState` called indirectly through a helper method invoked from within
the `Computed` callback is not detected in this version.

## Disabling

```yaml
all_observer:
  rules:
    - avoid_set_state_in_computed: false
```

## Evidence

Severity is `warning`; no blocking claim, no evidence document required.
