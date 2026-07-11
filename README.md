# all_observer_lint

Official lint rules for building safer Flutter and Dart apps with
[`all_observer`](https://github.com/CriandoGames/all_observer).

[Leia em português](README.pt-BR.md)

`all_observer_lint` helps catch common reactive mistakes directly in your IDE:
state created inside `build`, effects registered on every rebuild, invalid
`watch(context)` usage, impure `Computed` callbacks, and reactive resources that
were not disposed.

It is a development-only package. It does not change your app runtime.

## Install

Add both packages as development dependencies:

```bash
dart pub add --dev custom_lint all_observer_lint
```

For Flutter projects:

```bash
flutter pub add --dev custom_lint all_observer_lint
```

Your `pubspec.yaml` should contain:

```yaml
dev_dependencies:
  custom_lint: ^0.7.0
  all_observer_lint: ^0.1.0
```

`custom_lint` is required because it is the analyzer runner that loads custom
lint plugins. `all_observer_lint` provides the rules.

## Configure

In `analysis_options.yaml`, use the recommended preset:

```yaml
include: package:all_observer_lint/recommended.yaml
```

That preset enables the `custom_lint` analyzer plugin and the recommended rule
set.

To show diagnostics in Brazilian Portuguese:

```yaml
include: package:all_observer_lint/recommended.yaml

all_observer:
  language: pt-BR
```

## Run

Use your normal analyzer workflow:

```bash
dart analyze
```

Or run the custom lint runner directly:

```bash
dart run custom_lint
```

In Flutter projects:

```bash
flutter analyze
dart run custom_lint
```

Most IDEs show the diagnostics automatically after `pub get`.

## Example

This code creates reactive state every time the widget rebuilds:

```dart
Widget build(BuildContext context) {
  final count = 0.obs;
  return Text('${count.value}');
}
```

`all_observer_lint` reports:

```text
warning: Avoid creating reactive state inside build. The resource will be
recreated whenever the widget rebuilds. Move it to a State field, initState,
controller, view model, or another lifecycle-managed object.
```

Move the state to a lifecycle-managed place:

```dart
class _CounterPageState extends State<CounterPage> {
  final count = 0.obs;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${count.value}'));
  }
}
```

## Quick Fixes

Some rules provide IDE quick fixes. For example, `dispose_reactive_resources`
can add a missing `dispose()` call:

```dart
class _SearchPageState extends State<SearchPage> {
  late final worker = debounce(query, onSearch);

  @override
  void dispose() {
    worker.dispose();
    super.dispose();
  }
}
```

## Presets

| Preset | Use when |
|---|---|
| `recommended.yaml` | You want the default rule set for everyday projects. |
| `strict.yaml` | You also want experimental suggestions for cleaner reactive design. |
| `all.yaml` | You want to try every available rule. |

## Rules

| Rule | What it catches |
|---|---|
| [`avoid_reactive_creation_in_build`](documentation/en/rules/avoid_reactive_creation_in_build.md) | `Observable`, `.obs`, `Computed`, `ObservableFuture`, or `ObservableStream` created inside rebuild scopes. |
| [`avoid_effect_creation_in_build`](documentation/en/rules/avoid_effect_creation_in_build.md) | `effect`, `ever`, `once`, `debounce`, or `interval` registered inside rebuild scopes. |
| [`watch_only_inside_build`](documentation/en/rules/watch_only_inside_build.md) | `watch(context)` used outside widget build contexts. |
| [`dispose_reactive_resources`](documentation/en/rules/dispose_reactive_resources.md) | Workers/effects/streams stored in fields but not disposed. |
| [`avoid_reactive_write_in_computed`](documentation/en/rules/avoid_reactive_write_in_computed.md) | Reactive writes inside `Computed` callbacks. |
| [`avoid_set_state_in_computed`](documentation/en/rules/avoid_set_state_in_computed.md) | `setState` inside `Computed` callbacks. |
| [`avoid_worker_creation_in_computed`](documentation/en/rules/avoid_worker_creation_in_computed.md) | Workers/effects created inside `Computed` callbacks. |
| [`avoid_io_in_computed`](documentation/en/rules/avoid_io_in_computed.md) | `await` or obvious `dart:io` work inside `Computed` callbacks. |
| [`avoid_observable_write_during_observer_build`](documentation/en/rules/avoid_observable_write_during_observer_build.md) | Reactive writes while an `Observer` is building. |
| [`prefer_computed_for_derived_state`](documentation/en/rules/prefer_computed_for_derived_state.md) | Manual derived state that could be a `Computed`. |
| [`prefer_batch_for_multiple_related_writes`](documentation/en/rules/prefer_batch_for_multiple_related_writes.md) | Related reactive writes that may benefit from `batch`. |

## More Documentation

- [Example app](example/)
- [Architecture and why `custom_lint` is required](documentation/architecture.md)
- [Known limitations and future rules](documentation/backlog.md)
- [False positive policy](documentation/false_positives.md)

## License

MIT. See [LICENSE](LICENSE).
