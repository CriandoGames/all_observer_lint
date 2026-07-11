# Evidence: self_referencing_computed

## Problem

A `Computed` callback that reads the same `Computed` value it is currently
deriving creates a direct reactive cycle.

```dart
late final Computed<int> total = Computed(() {
  return total.value + 1;
});
```

The dependency graph contains a self edge:

```text
total -> total
```

That graph cannot produce a stable derived value because evaluating `total`
requires evaluating `total` again.

## Contract

`Computed` callbacks are derivations. They may read other reactive values, but
they must not depend on the `Computed` value currently being derived.

## Expected Behavior

Use another reactive source as input:

```dart
final count = 0.obs;

late final Computed<int> total = Computed(() {
  return count.value + 1;
});
```

## Lint Detection

The lint reports only the direct form that can be identified with high
confidence:

- the `Computed(...)` is assigned directly to a variable or field;
- the callback reads `.value`;
- that `.value` target resolves to the same variable or field.

## Automated Tests

Lint tests:

- `test/rules/self_referencing_computed_test.dart`
- `test/fixtures/consumer/lib/self_referencing_computed_invalid.dart`
- `test/fixtures/consumer/lib/self_referencing_computed_valid.dart`

The tests cover:

- direct field initializer self-reference;
- assignment self-reference;
- `this.field` assignment self-reference;
- reading another `Computed`;
- shadowed local names;
- homonymous `Computed` from another package;
- local functions that are not executed by the callback itself.

## Severity Decision

Severity: `error`.

Reason: this is a direct, deterministic reactive-cycle shape. Unlike broader
purity rules, this rule does not infer intent or flag arbitrary side effects; it
matches only a self-dependency in the derived value's own callback.

## Limitations

This evidence covers only direct self references. Longer cycles such as
`a -> b -> a` remain future work and must not be inferred from this rule.

Last validated: 2026-07-11.
