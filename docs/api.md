# API Reference

Alien Signals ships three layers. The primary deliverables are `system` and
`preset`; the surface API is a convenience wrapper.

## System API (package:alien_signals/system.dart)

Core dependency graph and propagation engine.

### Types
- `ReactiveFlags`: bit flags (`none`, `mutable`, `watching`, `recursedCheck`,
  `recursed`, `dirty`, `pending`).
- `ReactiveNode`: base class for graph nodes (fields: `flags`, `deps/depsTail`,
  `subs/subsTail`).
- `Link`: edge between `dep` and `sub`, with doubly-linked pointers and
  `version` tracking.
- `ReactiveSystem`: abstract core you implement.

### ReactiveSystem hooks
```dart
bool update(ReactiveNode node);
void notify(ReactiveNode node);
void unwatched(ReactiveNode node);
```

### ReactiveSystem helpers
- `link(dep, sub, version)`
- `unlink(link, sub)`
- `propagate(link)`
- `shallowPropagate(link)`
- `checkDirty(link, sub)`
- `isValidLink(checkLink, sub)`

Use this layer when you need custom primitives or scheduling semantics.

## Preset API (package:alien_signals/preset.dart)

Signals-style implementation on top of the system. This is the layer most
projects extend to build their own surface APIs.

### Node types
- `SignalNode<T>`: `get()`, `set()`, `didUpdate()`.
- `ComputedNode<T>`: `get()`, `didUpdate()`.
- `EffectNode<T>` / `LinkedEffect`: effect execution + queue linkage.
- `PresetReactiveSystem`: concrete `ReactiveSystem` implementation.

### Runtime helpers
- Dependency tracking: `activeSub`, `getActiveSub()`, `setActiveSub()`.
- Scheduling: `flush()`, `run(EffectNode e)`, `queuedEffects`, `queuedEffectsTail`.
- Batching: `startBatch()`, `endBatch()`, `getBatchDepth()`, `batchDepth`.
- Cleanup: `stop(ReactiveNode)`, `purgeDeps(ReactiveNode)`.
- Manual propagation: `trigger(() { ... })`.

Use this layer when you want signals semantics but with a custom surface API.

## Surface API (package:alien_signals/alien_signals.dart)

Thin wrapper on the preset for out-of-the-box signals.

```dart
WritableSignal<T> signal<T>(T initialValue)
Computed<T> computed<T>(T Function(T?) getter)
typedef EffectCleanup = void Function()
typedef EffectCallback<T> = T Function()
Effect effect<T>(EffectCallback<T> fn)
EffectScope effectScope(void Function() fn)
void startBatch()
void endBatch()
void trigger(void Function() fn)
```

Read signals with `value()` and write writable signals with `value.set(next)`.

Signal writes and computed results are compared with `identical`, not `==`.
Writing the same object does not notify dependents. For List/Map mutations in
place, call `trigger(() => value())` on the signal holding that object.

Computed getter errors are cached and rethrown until a tracked dependency
changes. Successful recomputation clears the error. After a failure, the
getter's previous-value argument remains the last successful value.

`effect()` runs immediately and tracks synchronous reads. Callbacks may return
a `void Function()` cleanup synchronously. Cleanup runs before the effect
re-runs and when it stops, without tracking its reads. Nested effects and scopes
stop before their parent's cleanup. Reads and nested effects/scopes after an
`await` are not tracked or owned by the original effect/scope.
