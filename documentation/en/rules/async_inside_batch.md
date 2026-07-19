# async_inside_batch

## Purpose

Warns when a directly supplied `Observable.batch` callback is statically
`async`. A batch is synchronous and cannot span an `await` boundary.

## Incorrect

```dart
Observable.batch(() async {
  await save();
});
```

## Correct

```dart
await save();
Observable.batch(() {
  first.value = 1;
  second.value = 2;
});
```

## Severity

`warning`; enabled in `recommended`, `strict`, and `all`.

## Limitations and possible false positives

The rule requires a resolved `all_observer` batch and direct static evidence
that the closure is async. It does not infer async behavior from called
functions, so false negatives are possible but speculative warnings are not.

## When to ignore

Ignore only when a forked runtime explicitly supports asynchronous batches.

## Fix or assist

No fix is offered because moving awaits can change ordering and error handling.
