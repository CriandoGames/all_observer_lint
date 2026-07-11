# unused_reactive_state

Reports private reactive state that is created but never referenced in the same
Dart file.

This rule is part of the `strict.yaml` and `all.yaml` presets. It is not part of
`recommended.yaml` because unused private state is usually a cleanup/design
signal, not a guaranteed runtime bug.

## Bad

```dart
class CounterController {
  final _count = 0.obs;

  void increment() {}
}
```

## Good

```dart
class CounterController {
  final _count = 0.obs;

  void increment() {
    _count.value++;
  }
}
```

## What it checks

The rule intentionally starts narrow. It only reports:

- private fields, such as `_count`;
- private top-level variables, such as `_currentUser`;
- initializers created with `.obs`, `Observable`, `Computed`,
  `ObservableFuture`, `ObservableStream`, or another recognized reactive type;
- symbols that have no resolved reference in the same Dart file.

Local variables are ignored because Dart already has general unused-local
diagnostics and because local reactive values often appear in short examples or
tests.
