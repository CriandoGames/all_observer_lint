# avoid_effect_creation_in_build

- **Category:** lifecycle
- **Severity:** warning
- **Blocking:** no
- **Preset:** `recommended`, `strict`, `all`
- **Quick fix:** no
- **Applies to `all_observer`:** all versions exposing `effect`, `ever`, `once`, `debounce`, `interval`

## What it does

Flags `effect(...)`, `ever(...)`, `once(...)`, `debounce(...)`, and
`interval(...)` registered directly inside a widget's `build` method or an
`Observer(...)` callback.

## Why

Every rebuild would register a brand-new subscription. None of these are
tied to the widget's lifecycle when created this way, so they accumulate —
duplicate side effects, duplicate analytics events, duplicate network
calls — for as long as the widget keeps rebuilding.

## Incorrect code

```dart
Widget build(BuildContext context) {
  effect(() {
    analytics.track(counter.value);
  });
  return Text('${counter.value}');
}
```

## Correct code

```dart
class _PageState extends State<Page> {
  late final Disposer _tracker = effect(() {
    analytics.track(counter.value);
  });

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('${counter.value}');
}
```

## Exceptions

Registrations inside a nested closure that is not itself a rebuild scope
(e.g. `onPressed: () { ever(...); }`) are not flagged.

## Limitations

Indirect registration through a helper function called from `build` is not
detected in this version.

## Disabling

```yaml
custom_lint:
  rules:
    - avoid_effect_creation_in_build: false
```

## Evidence

Severity is `warning`; no blocking claim, no evidence document required.
