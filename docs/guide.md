# Alien Signals Guide

## What This Repository Provides
Alien Signals is primarily a reusable reactive engine for Dart. It ships:
1) **system**: a generic `ReactiveSystem` with dependency tracking and
   propagation utilities.
2) **preset**: a high-performance signals implementation built on the system.
3) **surface API**: a small convenience layer built on the preset.

Most downstream projects either use **surface** directly or build their own
surface API on top of **preset** or **system**.

## Pick a Layer
- **Surface** (`package:alien_signals/alien_signals.dart`): you want signals
  immediately with zero customization.
- **Preset** (`package:alien_signals/preset.dart`): you want signals semantics
  but a custom API shape or naming.
- **System** (`package:alien_signals/system.dart`): you want custom primitives
  or a different scheduling model.

## System Model (Push/Pull)
The system uses a hybrid push/pull strategy:
- **Push**: `propagate` marks dependents as pending/dirty and schedules work.
- **Pull**: `checkDirty` lazily verifies and recomputes when values are read.

Why this matters:
- Push keeps dependency edges up-to-date and schedules effects promptly.
- Pull makes computed values lazy, avoiding wasted recomputation.

The preset combines both so effects run quickly while computed values stay
lazy and cache-friendly.

## Quick Start (Surface API)
```dart
import 'package:alien_signals/alien_signals.dart';

final count = signal(0);
final doubled = computed((prev) => count() * 2);
final stop = effect(() => print('count=${count()} doubled=${doubled()}'));

count.set(1);
// stop(); // stop effect
```

## Build Your Own Surface API (Preset)
The preset already implements signals semantics. You build a thin wrapper that
adapts it to your preferred API.

### 1) Wrap SignalNode
```dart
import 'package:alien_signals/preset.dart';
import 'package:alien_signals/system.dart';

class MySignal<T> extends SignalNode<T> {
  MySignal(T value)
      : super(flags: ReactiveFlags.mutable,
              currentValue: value,
              pendingValue: value);

  T call() => get();
}

MySignal<T> mySignal<T>(T value) => MySignal(value);
```

### 2) Wrap ComputedNode
```dart
class MyComputed<T> extends ComputedNode<T> {
  MyComputed(T Function(T?) getter)
      : super(flags: ReactiveFlags.none, getter: getter);

  T call() => get();
}

MyComputed<T> myComputed<T>(T Function(T?) getter) => MyComputed(getter);
```

### 3) Wrap EffectNode
`EffectNode` handles scheduling. This wrapper adds a disposable handle, but
constructing it alone does not execute or track the callback:
```dart
class MyEffect<T> extends EffectNode<T> {
  MyEffect(EffectCallback<T> fn)
      : super(flags: ReactiveFlags.watching | ReactiveFlags.recursedCheck,
              fn: fn);

  void call() => stop(this);
}
```

For a complete factory, follow `effect()` in `lib/src/surface.dart`: initialize
dependency tracking, link nested effects to their owner, maintain `runDepth`,
capture the cleanup returned by `runEffect()`, and restore tracking in `finally`.
The built-in surface API already handles this lifecycle.

### 4) Batching and manual propagation
Use the preset helpers directly:
```dart
startBatch();
try {
  // multiple writes
} finally {
  endBatch();
}

trigger(() {
  // access signals to notify their subscribers
});
```

If you want scopes, mirror `effectScope` from `lib/src/surface.dart`.

## Value and Lifecycle Semantics

- Signal writes and computed results use `identical`, not `==`. Setting the
  same object does not notify readers; after mutating a List or Map in place,
  use `trigger(() => value())`, where `value` is the signal holding it.
- Computed getters cache errors as well as values. A repeated read rethrows the
  cached error until a tracked dependency changes. A successful retry clears
  the error; the getter receives its last successful value as `prev`.
- Effects run immediately and track synchronous reads. A cleanup returned
  synchronously runs before the next execution and on stop, without tracking
  its reads. Nested effects and scopes stop before their parent's cleanup.
- Tracking and scope ownership do not continue across `await`. Reads after it
  are not dependencies, and effects created after it need their own disposal.

## Build Custom Primitives (System)
Use `ReactiveSystem` when you need different scheduling or new primitive types.
The system does **not** provide an "active subscriber" tracker or concrete
nodes; you build those yourself.

### Steps
1) Define your node types by extending `ReactiveNode` (store values, getters,
   or effect callbacks).
2) Maintain your own active-subscriber state and call `link(dep, sub, version)`
   when a dependency is read.
3) Implement `ReactiveSystem.update/notify/unwatched`.
4) On writes, call `propagate(dep.subs!)` and schedule work in `notify`.
5) Use `checkDirty` when computing derived values lazily.

Minimal skeleton:
```dart
class MySystem extends ReactiveSystem {
  @override
  bool update(ReactiveNode node) => /* recompute */ false;

  @override
  void notify(ReactiveNode node) {/* schedule or run */}

  @override
  void unwatched(ReactiveNode node) {/* cleanup */}
}
```

### Minimal Scheduling Example (System)
Below is a tiny queue-based scheduler showing how `notify` can defer work
until a flush. This mirrors the preset flow at a high level.
```dart
class MySystem extends ReactiveSystem {
  final queue = <ReactiveNode>[];
  bool flushing = false;

  @override
  bool update(ReactiveNode node) => /* recompute */ false;

  @override
  void notify(ReactiveNode node) {
    queue.add(node);
    if (!flushing) flush();
  }

  @override
  void unwatched(ReactiveNode node) {/* cleanup */}

  void flush() {
    flushing = true;
    while (queue.isNotEmpty) {
      final node = queue.removeLast();
      // Run effects or recompute nodes as needed.
    }
    flushing = false;
  }
}
```

For a concrete reference, inspect `lib/src/preset.dart`, which implements a
complete signals model on top of `ReactiveSystem`.

## Contributing Notes
Public APIs are exported via `lib/alien_signals.dart`. Core behavior lives in
`lib/src/system.dart` and `lib/src/preset.dart`. If you change those, update
`docs/api.md` and add tests.
