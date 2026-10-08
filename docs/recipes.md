# Recipes

If you are building a custom surface API, start with `docs/guide.md` for the
step-by-step preset and system workflows.

## Avoiding Leaky Effects
Always retain and stop effects you create in long-lived contexts.
```dart
final stop = effect(() => print(count()));
// later
stop();
```

Only synchronous reads are tracked. Read the reactive inputs before starting
asynchronous work; reads after `await` do not subscribe the effect.

Return a cleanup synchronously to release resources before the next run and
when stopping:

```dart
final stop = effect(() {
  final value = count();
  print('start $value');
  return () => print('stop $value');
});
```

Cleanup reads are not tracked. Nested effects/scopes stop before the parent's
cleanup runs.

## Scoped Cleanup
Use scopes when multiple effects should stop together.
```dart
final scope = effectScope(() {
  effect(() => print('one ${count()}'));
  effect(() => print('two ${count()}'));
});
// later
scope();
```

## Batching Updates
Batch writes to avoid redundant effect runs.
```dart
startBatch();
try {
  count.set(1);
  count.set(2);
} finally {
  endBatch();
}
```

## Derived State With Computed
Prefer `computed` for derived values; it caches and reuses results.
```dart
final total = computed((prev) => price() * qty());
```
If the getter throws, repeated reads rethrow the cached error until a tracked
dependency changes. A successful retry clears the error; `prev` remains the
last successful value after a failure.

## Manual Notification
Values use `identical` rather than `==` to detect changes. Mutating a List or
Map and setting the same instance does not notify dependents. Use `trigger` on
the signal holding it:
```dart
final items = signal(<String>[]);
final stop = effect(() => print(items().length));
items().add('new item');
trigger(() => items()); // prints: 1
stop();
```

## Testing Tips
- Keep tests focused and deterministic.
- Use `dart test` to run the suite.
- Name tests after behavior (for example, `computed_test.dart`).
