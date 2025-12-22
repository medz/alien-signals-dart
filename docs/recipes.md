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
count.set(1);
count.set(2);
endBatch();
```

## Derived State With Computed
Prefer `computed` for derived values; it caches and reuses results.
```dart
final total = computed((prev) => price() * qty());
```

## Manual Notification
Use `trigger` to notify dependents without creating a long-lived effect.
```dart
trigger(() {
  count();
});
```

## Testing Tips
- Keep tests focused and deterministic.
- Use `dart test` to run the suite.
- Name tests after behavior (for example, `computed_test.dart`).
