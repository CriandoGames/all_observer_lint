# watch_only_inside_build

- **Category:** widget-lifecycle
- **Severity:** warning
- **Blocking:** no
- **Preset:** `recommended`, `strict`, `all`
- **Quick fix:** no
- **Applies to `all_observer`:** all versions exposing `watch(context)`

## What it does

Flags `watch(context)` calls made outside a recognized widget build
context (a `build(BuildContext)` method or an `Observer` callback).

## Why

`watch(context)` ties a reactive read to the widget's rebuild cycle by
registering with the element tree. Calling it outside a build context does
not do what it looks like it does — there is no rebuild to tie the read to.

## Incorrect code

```dart
class _PageState extends State<Page> {
  void submit() {
    final value = counter.watch(context); // called outside build
    print(value);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: submit, child: const Text('submit'));
  }
}
```

## Correct code

```dart
@override
Widget build(BuildContext context) {
  return Text('${counter.watch(context)}');
}
```

If you need the value outside build, read `counter.value` directly, or use
an explicit `effect`/listener instead of `watch`.

## Exceptions

This rule is deliberately conservative. It stays silent whenever it cannot
prove the enclosing scope: a helper method that itself accepts a
`BuildContext` parameter is treated as ambiguous (it could legitimately
only ever be called from build) and is not flagged.

## Limitations

Calls made from top-level or local functions/closures are not analyzed
(also treated as ambiguous) in this version.

## Disabling

```yaml
custom_lint:
  rules:
    - watch_only_inside_build: false
```

## Evidence

Severity is `warning`; no blocking claim, no evidence document required.
