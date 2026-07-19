# dispose_reactive_resources

- **Category:** resource management
- **Severity:** warning
- **Preset:** `recommended`, `strict`, `all`
- **Quick fix:** yes, based on the resolved static type

## Purpose

Reports directly owned reactive resource fields that are not released in the
owning class's block-bodied `dispose()` method.

The verified contracts are:

| Type | Generated/recognized call |
|---|---|
| `Disposer` | `field()` |
| `Worker`, `Workers`, `ObservableHistory`, `ReactiveScope` | `field.dispose()` |
| `Computed`, `ObservableFuture`, `ObservableStream` | `field.close()` |
| `ObservableSubscription` | `field.cancel()` |

A plain `Observable` is intentionally not auto-closed by this rule.

## Incorrect

```dart
late final Disposer disposeEffect = effect(() => count.value);

void dispose() {
  super.dispose();
}
```

## Correct

```dart
void dispose() {
  disposeEffect();
  super.dispose();
}
```

## Limitations and possible false positives

Only fields with a direct, semantically resolved owned initializer are checked.
Classes without their own `dispose()` are skipped. A call inside conditional
control flow is accepted; path-sensitive lifecycle proof is not attempted.

Disposal delegated to a helper method *is* followed, but only narrowly: a
same-class, zero-parameter method called via a bare or `this.` target
(`_disposeResources()`, `this._disposeResources()`), directly or chained
through further such helpers. A helper that takes a parameter (e.g.
`_disposeWith(worker)`), lives in a different class/mixin, or is reached
only through a tear-off, is not followed, and can therefore still report a
false positive.

## When to ignore

Ignore when disposal is deliberately delegated through an ownership abstraction
that the local rule cannot follow.

## Fix or assist

The quick fix inserts the type-correct call before `super.dispose()`. It does
not synthesize lifecycle methods for arbitrary classes. No assist is attached.
