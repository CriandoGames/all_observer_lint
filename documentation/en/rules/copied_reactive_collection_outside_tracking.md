# copied_reactive_collection_outside_tracking

- **Category:** reactiveCycle
- **Severity:** info
- **Blocking:** no
- **Preset:** `strict`, `all` (not in `recommended`)
- **Quick fix:** no
- **Applies to `all_observer`:** any version
- **Status:** experimental

## What it does

Flags a local variable that copies an `ObservableList`/`ObservableMap`/
`ObservableSet` into a plain snapshot (`.toList()`/`.toSet()`) before an
`Observer`/`Computed`/`effect` tracking scope, when that snapshot — not the
original reactive collection — is what gets read inside the tracking
scope.

## Why

```dart
final visibleItems = items.toList();
return Observer(
  () => ListView(children: visibleItems.map(buildItem).toList()),
);
```

`visibleItems` is a plain `List`, copied before the `Observer` builder ever
ran. The `Observer` reads `visibleItems`, not `items` — it tracks nothing,
and will never rebuild when `items` changes. This is a common, easy-to-miss
mistake: the code compiles, renders correctly once, and only silently stops
updating.

## Incorrect code

```dart
final visibleItems = items.toList();
return Observer(
  () => Column(children: visibleItems.map((i) => Text('$i')).toList()),
);
```

## Correct code

Move the copy inside the tracking scope, so the read of `items` itself is
what gets tracked:

```dart
return Observer(
  () => Column(
    children: items.map((i) => Text('$i')).toList(),
  ),
);
```

Or, if the derived list is reused elsewhere, derive it with `Computed`
instead of a one-off snapshot:

```dart
late final visibleItems = Computed(() => items.toList());

return Observer(
  () => Column(children: visibleItems.value.map((i) => Text('$i')).toList()),
);
```

## Detection scope

This rule only recognizes:

- a **local** `final`/`var` variable declaration (a field snapshot is out
  of scope for this version — proving "read inside this tracking scope, in
  this method" for a field would need whole-class flow analysis this rule
  does not attempt);
- a `.toList()`/`.toSet()` snapshot (a spread collection-literal snapshot,
  e.g. `[...items]`, is not recognized yet — see the project's backlog).
  The reactive collection may be reached through one intermediate property
  first, e.g. `counters.keys.toList()` or `map.values.toSet()` on an
  `ObservableMap` — the chain is walked back to the original collection
  either way;
- the snapshot's own static type must not itself be a reactive collection,
  so `final same = items;` (which keeps tracking `items` directly) is
  never flagged;
- the snapshot variable must never be reassigned anywhere in the file — a
  variable refreshed before every use is not a stale snapshot;
- the original collection must be a statically resolvable simple
  reference (`items`, `this.items`, `widget.items`);
- the original collection must be confirmed **not** read inside the same
  tracking callback — when the original is also read there, the
  `Observer`/`Computed`/`effect` already tracks it correctly through that
  read, so this rule stays silent rather than risk a false positive.

## Limitations

- No quick fix or assist ships with this rule yet — only the diagnostic.
  Moving the snapshot expression into the tracking scope, or extracting it
  to a `Computed`, both need additional safety proof (single use, purity,
  a safe insertion point) not yet implemented.
- Instance-insensitive: the "was the original also read here" check
  compares the resolved field element, not the specific receiver instance.
  In the rare case where two different instances of the same class each
  expose their own `items` field and only one instance's field is read
  alongside the snapshot, this rule may stay silent (a false negative, not
  a false positive) rather than risk misattributing the read.
- A snapshot passed to a helper function/method that itself builds an
  `Observer` is not followed — only a tracking scope directly reachable in
  the same function body is considered.

## Disabling

```yaml
custom_lint:
  rules:
    - copied_reactive_collection_outside_tracking: false
```

## Evidence

`info` severity; a suggestion pointing at a statically provable
stale-tracking pattern, not a runtime-verified crash. No evidence document
required.
