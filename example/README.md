# all_observer_lint_example

Minimal Flutter app demonstrating [`all_observer_lint`](../)'s recommended
preset catching real reactive bugs, with a fixed version placed next to
each flagged one.

This package is not published — it exists only as a local demo alongside
the `all_observer_lint` repository (see `publish_to: none` in its
`pubspec.yaml`).

## Run

```bash
cd example
flutter pub get
dart run custom_lint
```

Each diagnostic raised here is documented in
[`documentation/en/rules/`](../documentation/en/rules/) (or
[`documentation/pt-BR/rules/`](../documentation/pt-BR/rules/) for
Portuguese).

## License

MIT. See [LICENSE](LICENSE) — same license as the parent
[`all_observer_lint`](../) package.
