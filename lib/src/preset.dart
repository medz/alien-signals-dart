import 'package:alien_signals/system.dart';

import 'surface.dart' show WritableSignal, Computed, Effect, EffectScope;

/// Version stamped on links, advanced by every rerun of an effect or computed.
int cycle = 0;

/// Current depth of nested effect callback execution.
///
/// Incremented by effect runs, not by standalone computed evaluation. When
/// greater than 0, writes should be treated as inner writes during propagation.
int runDepth = 0;

/// Depth of nested batches; effects wait while it is greater than 0.
int batchDepth = 0;

/// The running node that reads are linked to, if any.
ReactiveNode? activeSub;

/// First effect waiting for [flush].
LinkedEffect? queuedEffects;

/// Last effect waiting for [flush].
LinkedEffect? queuedEffectsTail;

const system = PresetReactiveSystem();

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
void propagate(Link link, [bool innerWrite = false]) =>
    system.propagate(link, innerWrite);

// Kept as tear-offs: calling these directly slowed deep chains in AOT.
final link = system.link,
    unlink = system.unlink,
    checkDirty = system.checkDirty,
    shallowPropagate = system.shallowPropagate;

/// Cleanup function returned by an effect callback.
typedef EffectCleanup = void Function();

/// Callback passed to an effect.
typedef EffectCallback<T> = T Function();

/// Marks a parent effect, scope, or computed whose deps include a child effect.
const hasChildEffect = 64 as ReactiveFlags;

/// A node that can wait in the effect queue.
class LinkedEffect({
  required super.flags,
  super.deps,
  super.depsTail,
  super.subs,
  super.subsTail,
}) extends ReactiveNode {
  /// Next effect in the queue.
  LinkedEffect? nextEffect;
}

/// A writable value of type [T].
///
/// Writes are held as pending and committed on the next read, so a value that
/// is restored before anyone reads it counts as unchanged.
class SignalNode<T>({
  required super.flags,

  /// The committed value.
  required var T currentValue,

  /// The latest written value, committed by the next update.
  required var T pendingValue,
}) extends ReactiveNode implements WritableSignal<T> {
  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  T call() => get();

  /// Writes [newValue] and, outside a batch, runs the affected effects.
  ///
  /// Does nothing if [newValue] is identical to the pending value.
  @override
  void set(T newValue) {
    if (!identical(pendingValue, newValue)) {
      pendingValue = newValue;
      flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
      if (subs case final Link subs) {
        propagate(subs, runDepth > 0);
        if (batchDepth == 0) flush();
      }
    }
  }

  /// Commits any pending write, then reads and tracks the value.
  T get() {
    if ((flags & ReactiveFlags.dirty) != .none) {
      if (didUpdate()) {
        final subs = this.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    }
    final sub = activeSub;
    if (sub != null) link(this, sub, cycle);
    return currentValue;
  }

  /// Commits the pending value and returns whether the value changed.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  bool didUpdate() {
    flags = .mutable;
    return !identical(currentValue, currentValue = pendingValue);
  }
}

/// A lazily computed, cached value derived from other nodes.
class ComputedNode<T>({
  required super.flags,

  /// Computes the value, given the previous successful value if any.
  required final T Function(T?) getter,
}) extends ReactiveNode implements Computed<T> {
  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  T call() => get();

  /// The cached computed value.
  ///
  /// Null until the first successful computation. A failed recomputation keeps
  /// the last successful value for the next call to [getter].
  T? currentValue;

  /// The cached error from the latest computation, if any.
  ///
  /// Errors are cached like values and retried after a dependency write. A
  /// write that restores a dependency's previous value is no change for a
  /// cached value, but it does retry a cached error.
  ({Object error, StackTrace stackTrace, _RetryDependency? retry})? _failure;

  void _cacheFailure(Object error, StackTrace stackTrace) {
    // No graph dependency means no dependency write can invalidate this node.
    final retry = depsTail != null
        ? _failure?.retry ?? _RetryDependency(this)
        : null;
    _failure = (error: error, stackTrace: stackTrace, retry: retry);
    if (retry != null) {
      retry.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
      link(retry, this, cycle);
    }
  }

  /// Recomputes the value if it is stale, then reads and tracks it.
  T get() {
    final flags = this.flags;
    if ((flags & (ReactiveFlags.dirty | ReactiveFlags.pending)) != .none) {
      if ((flags & ReactiveFlags.dirty) != .none || checkDirty(deps!, this)) {
        if (didUpdate()) {
          final subs = this.subs;
          if (subs != null) shallowPropagate(subs);
        }
      } else {
        this.flags = flags & ~ReactiveFlags.pending;
      }
    } else if (flags == .none) {
      this.flags = ReactiveFlags.mutable | ReactiveFlags.recursedCheck;
      final prevSub = setActiveSub(this);
      try {
        currentValue = getter(null);
      } on Object catch (error, stackTrace) {
        _cacheFailure(error, stackTrace);
      } finally {
        activeSub = prevSub;
        this.flags &= ~ReactiveFlags.recursedCheck;
      }
    }

    final sub = activeSub;
    if (sub != null) link(this, sub, cycle);

    final failure = _failure;
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }

    // Only null needs the runtime check against T.
    return currentValue ?? (null as T);
  }

  /// Reruns the getter and returns whether the value or error changed.
  bool didUpdate() {
    if ((flags & hasChildEffect) != .none) {
      disposeChildDepsInReverse(this);
    }
    depsTail = null;
    flags = ReactiveFlags.mutable | ReactiveFlags.recursedCheck;
    final prevSub = setActiveSub(this);
    try {
      ++cycle;
      final previousValue = currentValue;
      final previousFailure = _failure;
      final nextValue = getter(previousValue);
      currentValue = nextValue;
      if (previousFailure != null) _failure = null;
      return previousFailure != null || !identical(previousValue, nextValue);
    } on Object catch (error, stackTrace) {
      _cacheFailure(error, stackTrace);
      return true;
    } finally {
      activeSub = prevSub;
      flags &= ~ReactiveFlags.recursedCheck;
      purgeDeps(this);
    }
  }
}

// A terminal dependency added only after a failed computation. Its update
// checks the owner invalidation, after real dependencies settle iteratively.
final class _RetryDependency(final ComputedNode<Object?> owner)
    extends ReactiveNode {
  this : super(flags: ReactiveFlags.mutable | ReactiveFlags.dirty);
}

/// A reactive effect scope node that can participate in propagation.
class EffectScopeNode({required super.flags})
    extends ReactiveNode
    implements EffectScope {
  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  void call() => stopScope(this);

  /// Marks the scope as mutable while dirty checking propagates through it.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  bool didUpdate() {
    flags = .mutable;
    return true;
  }
}

/// A side effect that reruns when its dependencies change.
class EffectNode<T>({
  required super.flags,

  /// The side effect to run.
  required final EffectCallback<T> fn,

  /// Cleanup function returned by the latest effect execution.
  var EffectCleanup? cleanup,
}) extends LinkedEffect implements Effect {
  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  void call() => stop(this);

  /// Runs the effect callback and returns a cleanup if one was provided.
  EffectCleanup? runEffect() {
    final result = fn();
    // `is Function` cheaply rejects the common non-closure results.
    return result is Function && result is EffectCleanup ? result : null;
  }
}

/// The default reactive graph, scheduler, and cleanup implementation.
///
/// Dispatches updates to [SignalNode] and [ComputedNode], queues effects in
/// [notify], and releases unused dependencies in [unwatched]. The preset
/// helpers share this system and the active subscriber and batch state.
///
/// Use the node types to customize value accessors while retaining the
/// public surface API's effect lifecycle.
///
/// {@example /example/preset_playground.dart#wrappers}
class const PresetReactiveSystem() extends ReactiveSystem {
  /// Updates [node] and returns whether its value changed.
  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  bool update(ReactiveNode node) {
    return switch (node) {
      ComputedNode() => node.didUpdate(),
      SignalNode() => node.didUpdate(),
      EffectScopeNode() => node.didUpdate(),
      _RetryDependency() => (node.owner.flags & ReactiveFlags.pending) != .none,
      _ => false,
    };
  }

  /// Queues [effect] for [flush], after any watching parent effects.
  @override
  @pragma('vm:align-loops')
  void notify(ReactiveNode effect) {
    var current = effect as LinkedEffect;
    final tail = current;
    LinkedEffect? head;
    while (true) {
      current.nextEffect = head;
      head = current;
      current.flags &= ~ReactiveFlags.watching;

      final next = current.subs?.sub;
      if (next == null || (next.flags & ReactiveFlags.watching) == .none) break;
      current = next as LinkedEffect;
    }

    if (queuedEffectsTail == null) {
      queuedEffects = head;
    } else {
      queuedEffectsTail!.nextEffect = head;
    }
    queuedEffectsTail = tail;
  }

  /// Called when a node no longer has any subscribers.
  ///
  /// Computed nodes become dirty and release their dependencies lazily,
  /// signals stay alive, and effect-like nodes are stopped immediately.
  @override
  void unwatched(ReactiveNode node) {
    switch (node) {
      case ComputedNode():
        if (node.depsTail != null) {
          node.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
          disposeAllDepsInReverse(node);
        }
      case SignalNode():
        break;
      case _:
        stop(node);
    }
  }
}

/// Returns the running node that reads are linked to, if any.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
ReactiveNode? getActiveSub() => activeSub;

/// Links subsequent reads to [sub], or stops tracking when it is null.
///
/// Returns the previous subscriber, which the caller must restore.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
ReactiveNode? setActiveSub([ReactiveNode? sub]) {
  final prevSub = activeSub;
  activeSub = sub;
  return prevSub;
}

/// Returns the depth of nested batches; effects wait while it exceeds 0.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
int getBatchDepth() => batchDepth;

/// Starts a batch that defers effect execution until [endBatch].
///
/// Signal values remain readable during the batch. Nested batches are
/// supported; queued effects run when the outermost batch ends.
/// Always pair this call with [endBatch] in a `finally` block.
///
/// {@example /example/batch.dart#batch}
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
void startBatch() => ++batchDepth;

/// Ends a batch started by [startBatch].
///
/// When the outermost batch ends, immediately flushes all queued effects.
///
/// {@example /example/batch.dart#batch}
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
void endBatch() {
  if ((--batchDepth) == 0) flush();
}

/// Notifies subscribers of the signals read synchronously by [fn].
///
/// Use this after mutating a list or map in place. Setting the same object
/// does not notify readers because values are compared with [identical].
///
/// {@example /example/trigger.dart#trigger}
@pragma('vm:align-loops')
void trigger(void Function() fn) {
  final sub = ReactiveNode(flags: .watching), prevSub = setActiveSub(sub);
  try {
    fn();
  } finally {
    activeSub = prevSub;
    sub.flags = .none;
    Link? link = sub.deps;
    while (link != null) {
      final dep = link.dep;
      link = unlink(link, sub);

      final subs = dep.subs;
      if (subs != null) {
        propagate(subs, runDepth > 0);
        shallowPropagate(subs);
      }
    }
    if (batchDepth == 0) flush();
  }
}

/// Reruns a queued effect if a dependency changed, else resumes watching.
void run(EffectNode e) {
  final flags = e.flags;
  if ((flags & ReactiveFlags.dirty) != .none ||
      ((flags & ReactiveFlags.pending) != .none && checkDirty(e.deps!, e))) {
    if ((flags & hasChildEffect) != .none) {
      disposeChildDepsInReverse(e);
    }
    if (e.cleanup != null) {
      runCleanup(e);
      if (e.flags == .none) {
        return;
      }
    }
    e.depsTail = null;
    e.flags = ReactiveFlags.watching | ReactiveFlags.recursedCheck;
    final prevSub = setActiveSub(e);
    try {
      ++cycle;
      ++runDepth;
      e.cleanup = e.runEffect();
    } finally {
      --runDepth;
      activeSub = prevSub;
      e.flags &= ~ReactiveFlags.recursedCheck;
      purgeDeps(e);
    }
  } else if (e.deps != null) {
    e.flags = ReactiveFlags.watching | (flags & hasChildEffect);
  }
}

/// Runs all queued effects in order.
///
/// If one throws, the rest leave the queue and wait for their next change.
void flush() {
  try {
    while (queuedEffects != null) {
      final effect = queuedEffects as EffectNode;
      queuedEffects = effect.nextEffect;
      effect.nextEffect = null;
      if (queuedEffects == null) {
        queuedEffectsTail = null;
      }
      run(effect);
    }
  } finally {
    for (var effect = queuedEffects; effect != null;) {
      final next = effect.nextEffect;
      effect.flags |= ReactiveFlags.watching | ReactiveFlags.recursed;
      effect.nextEffect = null;
      effect = next;
    }
    queuedEffects = queuedEffectsTail = null;
  }
}

/// Stops [node], disposing its dependencies and running any effect cleanup.
///
/// Only the first subscriber is unlinked, which covers the single owner of an
/// effect or scope.
void stop(ReactiveNode node) {
  stopScope(node);
  if (node is EffectNode && node.cleanup != null) runCleanup(node);
}

/// Stops an effect after disposing its nested effects and scopes.
void stopEffect(EffectNode e) => stop(e);

/// Runs an effect cleanup outside dependency tracking.
void runCleanup(EffectNode e) {
  final cleanup = e.cleanup!;
  e.cleanup = null;
  final prevSub = activeSub;
  activeSub = null;
  try {
    cleanup();
  } finally {
    activeSub = prevSub;
  }
}

/// Stops a scope-like node and disposes all dependencies in reverse order.
void stopScope(ReactiveNode node) {
  node.flags = .none;
  disposeAllDepsInReverse(node);
  final subs = node.subs;
  if (subs != null) {
    unlink(subs, subs.sub);
  }
}

/// Disposes child effects/scopes while leaving signal/computed deps for purge.
void disposeChildDepsInReverse(ReactiveNode sub) {
  Link? link = sub.depsTail;
  while (link != null) {
    final prev = link.prevDep;
    final dep = link.dep;
    if (dep is! ComputedNode && dep is! SignalNode) {
      unlink(link, sub);
    }
    link = prev;
  }
}

/// Removes every dependency from [sub], starting from the newest link.
void disposeAllDepsInReverse(ReactiveNode sub) {
  // A node stopped mid-run still has stale links after depsTail; unlinking in
  // reverse needs depsTail to be the real end of the list.
  purgeDeps(sub);
  Link? link = sub.depsTail;
  while (link != null) {
    final prev = link.prevDep;
    unlink(link, sub);
    link = prev;
  }
}

/// Removes the dependencies that [sub] did not read in its latest run.
@pragma('vm:align-loops')
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
void purgeDeps(ReactiveNode sub) {
  final depsTail = sub.depsTail;
  Link? dep = depsTail != null ? depsTail.nextDep : sub.deps;
  while (dep != null) {
    dep = unlink(dep, sub);
  }
}
