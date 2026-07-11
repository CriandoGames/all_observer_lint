# unobserved_reactive_read_in_build

Reports reactive `.value` reads rendered directly inside a widget `build`
method without an observed context.

This rule is part of the `strict.yaml` and `all.yaml` presets. It is not part of
`recommended.yaml` yet because a direct `.value` read can sometimes be an
intentional one-time snapshot, but in normal UI rendering it usually means the
widget will not update when the reactive value changes.

## Bad

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Text(controller.name.value);
  }
}
```

## Good

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text(controller.name.value));
  }
}
```

Or:

```dart
Widget build(BuildContext context) {
  return Text(controller.name.watch(context));
}
```

## What it checks

The rule only reports `.value` reads whose target is resolved as an
`all_observer` reactive type and whose nearest rebuild scope is a Flutter
`build(BuildContext context)` method.

It intentionally ignores:

- reads inside `Observer`;
- reads through `watch(context)`;
- reads inside event handlers or other nested callbacks declared in `build`;
- non-reactive fields such as `bool isLoading = false`.
