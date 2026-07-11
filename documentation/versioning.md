# Compatibility and Versioning

## Supported Tooling

- Dart SDK: `>=3.3.0 <4.0.0`
- `analyzer`: `^7.0.0`
- `custom_lint_builder`: `^0.7.0`
- Consumer-side `custom_lint`: `^0.7.0`

`all_observer_lint` has no Flutter SDK dependency. Flutter is only required in
consumer projects that use Flutter-specific rules such as build-context and
widget-lifecycle checks.

## Why Consumers Need `custom_lint`

`all_observer_lint` contains the rules. `custom_lint` is the analyzer runner
that loads and executes those rules in the IDE and in commands such as
`dart run custom_lint`.

Dart packages do not activate analyzer plugins from transitive dependencies.
That is why consumer projects must declare both packages explicitly in
`dev_dependencies`.

## Versioning Policy

This package follows semantic versioning.

- Adding a new `info` rule, or adding a rule only to `all.yaml`, is a minor
  release.
- Adding a rule to `recommended.yaml` is documented as a notable minor release,
  because existing projects may start seeing new diagnostics.
- Promoting a rule from `warning` to `error`, or changing the default behavior
  of `recommended.yaml`, is called out clearly in the changelog because it can
  affect CI pipelines.

Rules are not promoted to `error` without reproducible evidence and technical
review. See [backlog.md](backlog.md) for the current promotion candidates and
known limitations.
