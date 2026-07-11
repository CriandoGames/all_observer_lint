# avoid_reactive_creation_in_build

- **Category:** lifecycle
- **Severity:** warning
- **Blocking:** no
- **Preset:** `recommended`, `strict`, `all`
- **Quick fix:** no (destination is ambiguous; see "Limitations")
- **Applies to `all_observer`:** all versions matching the API surface in this repository's brief (`Observable`, `.obs`, `Computed`, `ObservableFuture`, `ObservableStream`)

## What it does

Flags `Observable`, `.obs`, `Computed`, `ObservableFuture`, and
`ObservableStream` created directly inside a widget's `build(BuildContext)`
method, or inside an `Observer(...)` callback.

## Why

`build` and `Observer`'s callback both re-run on every rebuild/notification.
A reactive resource created there is a brand-new instance each time — any
state it held, and any listeners attached to the previous instance, are
silently discarded.

## Incorrect code

```dart
Widget build(BuildContext context) {
  final count = 0.obs;
  return Text('${count.value}');
}
```

```dart
Widget build(BuildContext context) {
  final total = Computed(() => price.value * quantity.value);
  return Observer(() => Text('${total.value}'));
}
```

## Correct code

```dart
class _CounterState extends State<Counter> {
  final count = 0.obs;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${count.value}'));
  }
}
```

## Exceptions / known false-positive-free cases

- Reactive resources created inside a nested closure that is *not* itself a
  rebuild scope (e.g. a button's `onPressed`) are not flagged — that
  closure runs on interaction, not on every rebuild.
- Symbols named `Observable`, `Computed`, etc. from a different package are
  never flagged (matching is done on the resolved library URI, never on
  name text alone).

## Limitations

- Detection only covers the direct forms above (constructor calls and
  `.obs`); creation hidden behind a factory/helper function is not
  detected in this version.
- The rule does not currently distinguish `StatelessWidget.build` from
  other widget-shaped methods with an identical signature declared outside
  Flutter; see `documentation/false_positives.md`.

## Disabling

```yaml
all_observer:
  rules:
    - avoid_reactive_creation_in_build: false
```

## Evidence

No blocking claim is made here (severity is `warning`), so no
`documentation/evidence/` entry is required per this project's policy —
see `documentation/backlog.md` for the promotion criteria that would apply
if this were ever proposed as `error`.
