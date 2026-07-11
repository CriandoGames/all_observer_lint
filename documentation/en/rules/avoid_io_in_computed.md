# avoid_io_in_computed

- **Category:** purity / async
- **Severity:** warning
- **Blocking:** no
- **Preset:** `recommended`, `all`
- **Quick fix:** no
- **Applies to `all_observer`:** any version

## What it does

Flags obvious I/O inside a `Computed` derivation callback: `await`
expressions, and calls/constructors resolved to `dart:io` (`File`,
`Socket`, `HttpClient`, etc.).

## Why

`Computed` is meant to be a synchronous, cheap, repeatable derivation. I/O
inside it can run far more often than intended (once per dependency
re-evaluation) and blocks the reactive graph while it does.

## Incorrect code

```dart
late final exists = Computed(() => File(path.value).existsSync());

late final data = Computed(() async {
  await Future<void>.delayed(Duration.zero);
  return path.value;
});
```

## Correct code

Use `ObservableFuture`/`ObservableStream` for asynchronous work, and keep
`Computed` limited to deriving from already-loaded reactive values.

## Exceptions

This is a best-effort, narrow detector, not a general purity checker: it
intentionally does not flag calls into arbitrary third-party
networking/database packages, to avoid false positives from a registry of
"known I/O APIs" that would inevitably be incomplete or wrong for some
project.

## Limitations

- Only `dart:io` and `await` are recognized; HTTP client packages,
  platform channels, and similar are not detected in this version (see
  `documentation/backlog.md`).
- Synchronous, non-`dart:io` blocking calls (e.g. heavy CPU work) are out
  of scope for this rule.

## Disabling

```yaml
custom_lint:
  rules:
    - avoid_io_in_computed: false
```

## Evidence

Severity is `warning`; no blocking claim, no evidence document required.
