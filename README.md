# all_observer_lint

Official lint rules and automated fixes for safe, predictable, and
efficient development with [`all_observer`](https://github.com/CriandoGames/all_observer).

[Leia em português](README.pt-BR.md)

`all_observer_lint` does not compete with generic Dart/Flutter style rules
(quotes, line length, import ordering, and so on). Every rule here is
specific to `all_observer`: reactive resource lifecycle, `Computed`
purity, `Observer`/`watch` correctness, and resource disposal.

## Relationship to `all_observer`

`all_observer_lint` is a separate, `dev_dependency`-only package. It never
adds a runtime dependency to your app — it only analyzes your code and
reports diagnostics through `dart analyze` / your IDE. `all_observer`
itself (the reactive library) is unaffected either way.

## Installation

```yaml
dev_dependencies:
  all_observer_lint: ^0.1.0
  custom_lint: ^0.7.0
```

## Configuration

In your `analysis_options.yaml`:

```yaml
include: package:all_observer_lint/recommended.yaml
```

That single line enables the `custom_lint` analyzer plugin and the
recommended rule set. To use Brazilian Portuguese diagnostics instead of
English:

```yaml
include: package:all_observer_lint/recommended.yaml

all_observer:
  language: pt-BR
```

To disable an individual rule:

```yaml
include: package:all_observer_lint/recommended.yaml

all_observer:
  rules:
    - avoid_io_in_computed: false
```

Run `dart run custom_lint` (or let your IDE's analysis server pick it up
automatically) to see diagnostics.

## Presets

| Preset | Contents |
|---|---|
| `recommended.yaml` | Lifecycle + purity rules with a low false-positive rate. Safe default for any project. |
| `strict.yaml` | `recommended.yaml` plus experimental, opinionated `info`-level suggestions (`prefer_computed_for_derived_state`, `prefer_batch_for_multiple_related_writes`). |
| `all.yaml` | Every rule this package ships, including experimental ones. Mainly useful for evaluating new rules. |

## Rules

| Rule | Severity | Preset |
|---|---|---|
| [`avoid_reactive_creation_in_build`](documentation/en/rules/avoid_reactive_creation_in_build.md) | warning | recommended |
| [`avoid_effect_creation_in_build`](documentation/en/rules/avoid_effect_creation_in_build.md) | warning | recommended |
| [`watch_only_inside_build`](documentation/en/rules/watch_only_inside_build.md) | warning | recommended |
| [`dispose_reactive_resources`](documentation/en/rules/dispose_reactive_resources.md) | warning | recommended |
| [`avoid_reactive_write_in_computed`](documentation/en/rules/avoid_reactive_write_in_computed.md) | warning | recommended |
| [`avoid_set_state_in_computed`](documentation/en/rules/avoid_set_state_in_computed.md) | warning | recommended |
| [`avoid_worker_creation_in_computed`](documentation/en/rules/avoid_worker_creation_in_computed.md) | warning | recommended |
| [`avoid_io_in_computed`](documentation/en/rules/avoid_io_in_computed.md) | warning | recommended |
| [`avoid_observable_write_during_observer_build`](documentation/en/rules/avoid_observable_write_during_observer_build.md) | warning | recommended |
| [`prefer_computed_for_derived_state`](documentation/en/rules/prefer_computed_for_derived_state.md) | info | strict |
| [`prefer_batch_for_multiple_related_writes`](documentation/en/rules/prefer_batch_for_multiple_related_writes.md) | info | strict |

No rule ships as `error` in this release — see
`documentation/backlog.md` for the evidence-based promotion path.

## Example diagnostic

```dart
Widget build(BuildContext context) {
  final count = 0.obs; // avoid_reactive_creation_in_build
  return Text('${count.value}');
}
```

```
warning: Avoid creating reactive state inside build. The resource will be
recreated whenever the widget rebuilds. Move it to a State field,
initState, controller, view model, or another lifecycle-managed object.
  --> lib/counter.dart:3:17
```

## Example quick fix

`dispose_reactive_resources` offers a quick fix that inserts the missing
disposal call:

```dart
// Before (flagged)
class _SearchPageState extends State<SearchPage> {
  late final worker = debounce(query, onSearch);

  @override
  void dispose() {
    super.dispose();
  }
}

// After applying the quick fix
class _SearchPageState extends State<SearchPage> {
  late final worker = debounce(query, onSearch);

  @override
  void dispose() {
    worker.dispose();
    super.dispose();
  }
}
```

See `example/` for a runnable Flutter app with more flagged/fixed pairs.

## Compatibility

- Dart SDK: `>=3.3.0 <4.0.0`
- `analyzer`: `^7.0.0`
- `custom_lint_builder` / `custom_lint`: `^0.7.0`
- Flutter: required only by rules that concern widget lifecycle
  (`avoid_reactive_creation_in_build`, `avoid_effect_creation_in_build`,
  `watch_only_inside_build`, `avoid_observable_write_during_observer_build`,
  `avoid_set_state_in_computed`); the package itself has no Flutter SDK
  dependency (see `documentation/architecture.md`).

Version constraints here are intentionally not pinned tighter than
necessary; a breaking upstream `analyzer`/`custom_lint` release will be
handled with a documented package major-version bump, not silently.

## Versioning policy

`all_observer_lint` follows semver for its own package version. Within
that:

- Adding a new `info`-level rule, or adding a rule to `all.yaml` only, is
  a **minor** release.
- Adding a rule to `recommended.yaml` (which can turn on new diagnostics
  in existing projects without any action from the consumer) is
  documented in the changelog as a notable minor release, even though it
  is not technically breaking.
- Promoting a rule from `warning` to `error`, or changing default behavior
  of `recommended.yaml`, is called out explicitly in the changelog as a
  potentially pipeline-breaking change (see `documentation/backlog.md`,
  section "Provas antes de bloquear o CI" in the project brief).

## Contributing

Issues and pull requests are welcome at the repository above. Before
proposing a new rule, please read `documentation/architecture.md` (how
matching works) and `documentation/backlog.md` (what's already been
considered and why it isn't shipped yet). Rule proposals should follow the
same template as the existing docs under `documentation/en/rules/`.

## License

MIT, see `LICENSE`.
