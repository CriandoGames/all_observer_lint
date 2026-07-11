# dispose_reactive_resources

- **Category:** resource-management
- **Severity:** warning
- **Blocking:** no
- **Preset:** `recommended`, `strict`, `all`
- **Quick fix:** yes — inserts `<field>.dispose();` as the first statement of `dispose()`
- **Applies to `all_observer`:** versions where `effect`/`ever`/`once`/`debounce`/`interval` return a disposable handle, and `ObservableStream` exposes `dispose()`

## What it does

Flags a field holding an effect/worker or an `ObservableStream` that is
never disposed inside the owning class's `dispose()` method.

## Why

Undisposed workers keep listening after their owner is gone: stale
callbacks, duplicated side effects on hot reload/rebuild cycles, and
memory that never gets released.

## Incorrect code

```dart
class _SearchPageState extends State<SearchPage> {
  late final worker = debounce(query, onSearch, time: const Duration(milliseconds: 400));

  @override
  void dispose() {
    super.dispose(); // worker is never disposed
  }
}
```

## Correct code

```dart
class _SearchPageState extends State<SearchPage> {
  late final worker = debounce(query, onSearch, time: const Duration(milliseconds: 400));

  @override
  void dispose() {
    worker.dispose();
    super.dispose();
  }
}
```

## Exceptions

A class with no `dispose()` method of its own is not flagged: without a
lifecycle method to check against, ownership is ambiguous and this rule
would rather stay silent than guess.

## Limitations (first version)

- Only fields are checked, not local variables.
- The field's initializer must be a direct
  `effect`/`ever`/`once`/`debounce`/`interval`/`ObservableStream(...)`
  expression; disposal ownership transferred through a helper method is
  not tracked yet.
- Disposal is recognized as any `<field>.dispose()` call anywhere in
  `dispose()`, regardless of control flow (e.g. inside an `if`) — a future
  version may tighten this once real-world false negatives are collected.

## Disabling

```yaml
all_observer:
  rules:
    - dispose_reactive_resources: false
```

## Evidence

Severity is `warning`; no blocking claim, no evidence document required.
