# prefer_computed_for_derived_state

- **Category:** architecture
- **Severity:** info
- **Blocking:** no
- **Preset:** `strict`, `all` (not in `recommended`)
- **Quick fix:** no
- **Applies to `all_observer`:** any version
- **Status:** experimental

## What it does

Flags an observable assigned a value derived purely from other
observables' `.value` — a manual re-derivation `Computed` already solves
declaratively.

## Why

Manually kept-in-sync state drifts: every place that changes one of the
source observables must remember to also update the derived one. `Computed`
makes that relationship automatic and impossible to forget.

## Incorrect code

```dart
final firstName = ''.obs;
final lastName = ''.obs;
final fullName = ''.obs;

void updateFullName() {
  fullName.value = '${firstName.value} ${lastName.value}';
}
```

## Correct code

```dart
final firstName = ''.obs;
final lastName = ''.obs;
final fullName = Computed(() => '${firstName.value} ${lastName.value}');
```

## Exceptions

An assignment that also reads its own target's `.value` (accumulation,
e.g. `total.value = total.value + delta`) is not flagged — that is not a
pure re-derivation.

## Limitations

This is intentionally conservative and experimental: it only looks at a
single plain (`=`) assignment statement's right-hand side, not the whole
method. It is not included in `recommended` because false positives are
more likely here than in the lifecycle/purity rules (e.g. a value that
looks "purely derived" today may legitimately need extra state later).

## Disabling

```yaml
all_observer:
  rules:
    - prefer_computed_for_derived_state: false
```

## Evidence

`info` severity; a suggestion, not a claim of a bug. No evidence document
required.
