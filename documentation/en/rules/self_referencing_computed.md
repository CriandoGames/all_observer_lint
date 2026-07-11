# self_referencing_computed

- Category: reactive-cycle
- Severity: error
- Preset: recommended
- Quick fix: no
- Applies to: `all_observer` `Computed`

## What It Catches

A `Computed` value reading its own `.value` inside the callback used to derive
that same `Computed`.

## Why

`Computed` callbacks must derive a value from other reactive inputs. Reading the
same `Computed` while it is being derived creates a direct reactive cycle: the
value depends on itself and the graph cannot stabilize.

## Invalid

```dart
class CounterState {
  late final Computed<int> total = Computed(() {
    return total.value + 1;
  });
}
```

## Valid

```dart
class CounterState {
  final count = 0.obs;

  late final Computed<int> total = Computed(() {
    return count.value + 1;
  });
}
```

Reading another `Computed` is also valid:

```dart
class CounterState {
  final count = 0.obs;

  late final Computed<int> doubled = Computed(() => count.value * 2);
  late final Computed<int> quadrupled = Computed(() => doubled.value * 2);
}
```

## Limitations

This rule is intentionally narrow. It only reports direct self references where
the `Computed(...)` is assigned directly to a variable or field and the callback
reads `.value` from that same resolved symbol.

It does not try to detect longer dependency cycles such as `a -> b -> a`.

## Evidence

See [self_referencing_computed.md](../../evidence/self_referencing_computed.md).

## Disable

```yaml
include: package:all_observer_lint/recommended.yaml

custom_lint:
  rules:
    self_referencing_computed: false
```
