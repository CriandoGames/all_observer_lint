# prefer_assign_all_for_reactive_list_replace

- **Category:** performance
- **Severity:** info
- **Blocking:** no
- **Preset:** `strict`, `all` (not in `recommended`)
- **Quick fix:** no
- **Applies to `all_observer`:** versions exposing `ObservableList.assign` and `ObservableList.assignAll`
- **Status:** experimental

## What it does

Flags an `ObservableList.clear()` call immediately followed by `add(...)` or
`addAll(...)` on the same observable list.

## Why

Replacing a reactive list with `clear()` and then `add`/`addAll` expresses one
logical update as two mutations. Observers can be notified twice, and code can
briefly observe an empty list between the two statements.

Use `assign(...)` for a single replacement item and `assignAll(...)` for a
replacement collection. Those APIs express replacement directly and notify as
one operation.

## Incorrect code

```dart
void replace(List<Todo> nextTodos) {
  todos.clear();
  todos.addAll(nextTodos);
}
```

```dart
void replaceWithOne(Todo todo) {
  todos.clear();
  todos.add(todo);
}
```

## Suggested code

```dart
void replace(List<Todo> nextTodos) {
  todos.assignAll(nextTodos);
}
```

```dart
void replaceWithOne(Todo todo) {
  todos.assign(todo);
}
```

## Exceptions

The rule only flags immediate consecutive statements in the same block and on
the same `ObservableList`.

It does not flag:

- `clear()` without a following `add`/`addAll`.
- plain Dart `List` instances.
- mutations on a different list.
- conditional or delayed `add`/`addAll` calls.

## Limitations

This rule does not attempt to infer intent across branches, helper methods, or
aliases. It is intentionally narrow so the diagnostic remains a clear
replacement suggestion instead of a general collection-mutation warning.

## Disabling

```yaml
all_observer:
  rules:
    - prefer_assign_all_for_reactive_list_replace: false
```

## Evidence

`info` severity; this is an optimization and clarity suggestion. It is not a
blocking correctness rule.
