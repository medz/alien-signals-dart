import 'package:alien_signals/system.dart';

/// Global version counter for tracking dependency updates.
///
/// Incremented whenever a reactive computation runs to ensure
/// dependencies are properly tracked and invalidated.
int cycle = 0;

/// Current depth of nested batch operations.
///
/// When greater than 0, effect execution is deferred until
/// all batches complete to avoid redundant computations.
int batchDepth = 0;

/// The currently active subscriber node.
///
/// Used during reactive computations to automatically track
/// dependencies. When a signal is accessed, it links itself
/// to this active subscriber.
ReactiveNode? activeSub;

/// Head of the queue of effects waiting to be executed.
///
/// Effects are queued during propagation and executed
/// together when the batch completes or flush is called.
LinkedEffect? queuedEffects;

/// Tail of the effects queue for O(1) append operations.
LinkedEffect? queuedEffectsTail;

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
const system = PresetReactiveSystem();

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
final link = system.link,
    unlink = system.unlink,
    propagate = system.propagate,
    checkDirty = system.checkDirty,
    shallowPropagate = system.shallowPropagate;

/// A reactive node that can be linked in a queue of effects.
///
/// Extends [ReactiveNode] to add queueing capabilities, allowing
/// effects to be scheduled and executed in batch for efficiency.
///
/// Used internally by the effect system to manage execution order
/// and avoid redundant computations during reactive updates.
class LinkedEffect extends ReactiveNode {
  /// Next effect in the execution queue.
  ///
  /// Forms a singly-linked list of effects waiting to be executed.
  LinkedEffect? nextEffect;

  LinkedEffect({
    required super.flags,
    super.deps,
    super.depsTail,
    super.subs,
    super.subsTail,
  });
}

/// A reactive signal node that holds a value of type [T].
///
/// SignalNode is the core primitive for reactive state. It stores
/// a value that can be read and written, automatically tracking
/// dependencies and notifying subscribers when the value changes.
///
/// The node maintains both current and pending values to support
/// batched updates and ensure consistency during propagation.
class SignalNode<T> extends ReactiveNode {
  /// The current committed value of the signal.
  T currentValue;

  /// The pending value to be committed on the next update.
  ///
  /// Allows for batching multiple changes before propagation.
  T pendingValue;

  SignalNode({
    required super.flags,
    required this.currentValue,
    required this.pendingValue,
  });

  /// Sets a new value for the signal.
  ///
  /// If the new value differs from the pending value, marks the
  /// signal as dirty and propagates changes to all subscribers.
  ///
  /// If not in a batch (batchDepth == 0), immediately flushes
  /// all queued effects.
  void set(T newValue) {
    if (!identical(pendingValue, newValue)) {
      pendingValue = newValue;
      flags =
          17 /*ReactiveFlags.mutable | ReactiveFlags.dirty*/ as ReactiveFlags;
      if (subs case final Link subs) {
        propagate(subs);
        if (batchDepth == 0) flush();
      }
    }
  }

  /// Gets the current value of the signal.
  ///
  /// If the signal is dirty, updates it first. Automatically
  /// establishes a dependency relationship with the active
  /// subscriber if one exists.
  ///
  /// Returns the current committed value.
  @pragma('vm:align-loops')
  T get() {
    if ((flags & ReactiveFlags.dirty) != ReactiveFlags.none) {
      if (didUpdate()) {
        final subs = this.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    }
    ReactiveNode? sub = activeSub;
    while (sub != null) {
      if ((sub.flags &
              3 /*(ReactiveFlags.mutable | ReactiveFlags.watching)*/) !=
          ReactiveFlags.none) {
        link(this, sub, cycle);
        break;
      }
      sub = sub.subs?.sub;
    }
    return currentValue;
  }

  /// Updates the signal's current value from its pending value.
  ///
  /// Returns `true` if the value changed, `false` otherwise.
  /// Used internally during propagation to commit pending changes.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  bool didUpdate() {
    flags = ReactiveFlags.mutable;
    return !identical(currentValue, currentValue = pendingValue);
  }
}

/// A reactive computed node that derives its value from other reactive nodes.
///
/// ComputedNode automatically tracks its dependencies and recalculates
/// its value when any dependency changes. The computation is lazy -
/// it only runs when the value is accessed and dependencies have changed.
///
/// Computed nodes cannot be directly written to; they always derive
/// their value from the getter function.
class ComputedNode<T> extends ReactiveNode {
  /// The function that computes this node's value.
  ///
  /// Receives the previous value as a parameter, which can be
  /// useful for incremental computations.
  final T Function(T?) getter;

  /// The cached computed value.
  ///
  /// Null until first computation or after invalidation.
  T? currentValue;

  ComputedNode({required super.flags, required this.getter});

  /// Gets the computed value, recalculating if necessary.
  ///
  /// Checks if the value is dirty or pending, and if so,
  /// re-runs the getter function. Automatically tracks
  /// dependencies accessed during computation.
  ///
  /// Returns the computed value.
  T get() {
    final flags = this.flags;
    if ((flags & ReactiveFlags.dirty) != ReactiveFlags.none ||
        ((flags & ReactiveFlags.pending) != ReactiveFlags.none &&
            (checkDirty(deps!, this) ||
                identical(this.flags = flags & -33 /*~ReactiveFlags.pending*/,
                    false)))) {
      if (didUpdate()) {
        final subs = this.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    } else if (flags == ReactiveFlags.none) {
      this.flags = 5 /*ReactiveFlags.mutable | ReactiveFlags.recursedCheck*/
          as ReactiveFlags;
      final prevSub = setActiveSub(this);
      try {
        currentValue = getter(null);
      } finally {
        activeSub = prevSub;
        this.flags &= -5 /*~ReactiveFlags.recursedCheck*/;
      }
    }

    final sub = activeSub;
    if (sub != null) link(this, sub, cycle);

    return currentValue as T;
  }

  /// Updates the computed value by re-running the getter.
  ///
  /// Clears old dependencies, runs the getter with dependency
  /// tracking enabled, and returns whether the value changed.
  ///
  /// Returns `true` if the computed value changed, `false` otherwise.
  bool didUpdate() {
    ++cycle;
    depsTail = null;
    flags = ReactiveFlags.mutable | ReactiveFlags.recursedCheck;
    final prevSub = setActiveSub(this);
    try {
      return !identical(currentValue, currentValue = getter(currentValue));
    } finally {
      activeSub = prevSub;
      flags &= -5 /*~ReactiveFlags.recursedCheck*/;
      purgeDeps(this);
    }
  }
}

/// A reactive effect node that runs side effects in response to changes.
///
/// EffectNode extends [LinkedEffect] to add the capability to execute
/// a function when its dependencies change. Effects are the bridge
/// between the reactive system and the outside world, allowing
/// side effects like DOM updates or logging.
class EffectNode extends LinkedEffect {
  /// The side effect function to execute.
  ///
  /// This function is called whenever any of the effect's
  /// dependencies change.
  final void Function() fn;

  EffectNode({required super.flags, required this.fn});
}

/// Default implementation of the reactive system for Alien Signals.
///
/// PresetReactiveSystem provides the standard reactive behavior used by
/// the alien_signals library. It implements the abstract [ReactiveSystem]
/// methods to manage signal updates, effect scheduling, and dependency cleanup.
///
/// This implementation features:
/// - **Type-based dispatch**: Uses pattern matching to handle different node types
/// - **Effect batching**: Queues effects for efficient batch execution
/// - **Lazy cleanup**: Delays dependency cleanup for mutable nodes until needed
/// - **Automatic propagation**: Handles change propagation through the reactive graph
///
/// The system maintains global state including:
/// - Effect queue ([queuedEffects]/[queuedEffectsTail])
/// - Batch depth tracking ([batchDepth])
/// - Active subscriber tracking ([activeSub])
/// - Version tracking ([cycle])
///
/// ## Internal Operation
///
/// When a signal changes:
/// 1. The change propagates through [propagate] to mark dependents
/// 2. Effects are queued via [notify] for batch execution
/// 3. When batch completes, [flush] executes all queued effects
/// 4. Each effect's dependencies are tracked during execution
///
/// ## Usage
///
/// This class is used internally by the library and is instantiated as
/// a singleton constant:
///
/// ```dart
/// const system = PresetReactiveSystem();
/// ```
///
/// Most users don't interact with this class directly - they use the
/// high-level API functions like `signal()`, `computed()`, and `effect()`
/// which internally use this system.
class PresetReactiveSystem extends ReactiveSystem {
  const PresetReactiveSystem();

  /// Updates a reactive node's value.
  ///
  /// Dispatches to the appropriate update method based on node type.
  /// For [ComputedNode] and [SignalNode], calls their update methods.
  /// For other node types, returns false (no update needed).
  ///
  /// Returns `true` if the node's value changed, `false` otherwise.
  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  bool update(ReactiveNode node) {
    return switch (node) {
      ComputedNode() => node.didUpdate(),
      SignalNode() => node.didUpdate(),
      _ => false,
    };
  }

  /// Queues an effect for execution.
  ///
  /// Adds the effect and any watching parent effects to the
  /// execution queue. Effects are executed together when
  /// [flush] is called or when a batch completes.
  ///
  /// This batching mechanism prevents redundant computations
  /// and ensures effects run in a consistent order.
  @override
  @pragma('vm:align-loops')
  void notify(ReactiveNode effect) {
    LinkedEffect? head;
    final LinkedEffect tail = effect as LinkedEffect;

    do {
      effect.flags &= -3 /*~ReactiveFlags.watching*/;
      (effect as LinkedEffect).nextEffect = head;
      head = effect;

      final next = effect.subs?.sub;
      if (next == null ||
          ((effect = next).flags & ReactiveFlags.watching) ==
              ReactiveFlags.none) {
        break;
      }
    } while (true);

    if (queuedEffectsTail == null) {
      queuedEffects = queuedEffectsTail = head;
    } else {
      queuedEffectsTail!.nextEffect = head;
      queuedEffectsTail = tail;
    }
  }

  /// Called when a node no longer has any subscribers.
  ///
  /// For non-mutable nodes (like effects), stops them completely.
  /// For mutable nodes (like signals), marks them as dirty and
  /// clears their dependencies for lazy re-evaluation.
  @override
  void unwatched(ReactiveNode node) {
    if ((node.flags & ReactiveFlags.mutable) == ReactiveFlags.none) {
      stop(node);
    } else if (node.depsTail != null) {
      node.depsTail = null;
      node.flags =
          17 /*ReactiveFlags.mutable | ReactiveFlags.dirty*/ as ReactiveFlags;
      purgeDeps(node);
    }
  }
}

/// Gets the currently active subscriber node.
///
/// The active subscriber is the node currently being computed,
/// which will be linked as a dependency to any signals accessed.
///
/// Returns the active subscriber or `null` if none is active.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
ReactiveNode? getActiveSub() => activeSub;

/// Sets the active subscriber node and returns the previous one.
///
/// Used to establish a reactive context where dependencies
/// are automatically tracked. The previous subscriber should
/// be restored after the reactive computation completes.
///
/// Returns the previous active subscriber.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
ReactiveNode? setActiveSub([ReactiveNode? sub]) {
  final prevSub = activeSub;
  activeSub = sub;
  return prevSub;
}

/// Gets the current batch depth.
///
/// A depth greater than 0 indicates that updates are being
/// batched and effects are deferred.
///
/// Returns the current batch depth.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
int getBatchDepth() => batchDepth;

/// Starts a new batch operation.
///
/// While in a batch, effect execution is deferred to avoid
/// redundant computations. Multiple nested batches are supported.
/// Effects are executed when all batches complete.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
void startBatch() => ++batchDepth;

/// Ends the current batch operation.
///
/// Decrements the batch depth. If this was the last batch
/// (depth reaches 0), immediately flushes all queued effects.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
void endBatch() {
  if ((--batchDepth) == 0) flush();
}

/// Manually triggers reactive updates within a function.
///
/// Creates a temporary reactive context and executes the given
/// function. Any signals accessed during execution will be
/// tracked, and their subscribers will be notified of changes.
///
/// Useful for imperatively triggering updates in the reactive
/// system without creating a permanent effect.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// trigger(() {
///   count(); // Access triggers propagation to subscribers
/// });
/// ```
@pragma('vm:align-loops')
void trigger(void Function() fn) {
  final sub = ReactiveNode(flags: ReactiveFlags.watching),
      prevSub = setActiveSub(sub);
  try {
    fn();
  } finally {
    activeSub = prevSub;
    Link? link = sub.deps;
    while (link != null) {
      final dep = link.dep;
      link = unlink(link, sub);

      final subs = dep.subs;
      if (subs != null) {
        sub.flags = ReactiveFlags.none;
        propagate(subs);
        shallowPropagate(subs);
      }
    }
    if (batchDepth == 0) flush();
  }
}

/// Executes an effect node if it needs updating.
///
/// Checks if the effect is dirty or has pending updates,
/// and if so, runs its function with dependency tracking.
/// Otherwise, just marks it as watching.
///
/// This is called internally when flushing queued effects.
void run(EffectNode e) {
  final flags = e.flags;
  if ((flags & ReactiveFlags.dirty) != ReactiveFlags.none ||
      ((flags & ReactiveFlags.pending) != ReactiveFlags.none &&
          checkDirty(e.deps!, e))) {
    ++cycle;
    e.depsTail = null;
    e.flags = 6 /*ReactiveFlags.watching | ReactiveFlags.recursedCheck*/
        as ReactiveFlags;
    final prevSub = setActiveSub(e);
    try {
      e.fn();
    } finally {
      activeSub = prevSub;
      e.flags &= -5 /*~ReactiveFlags.recursedCheck*/;
      purgeDeps(e);
    }
  } else {
    e.flags = ReactiveFlags.watching;
  }
}

/// Flushes all queued effects, executing them in order.
///
/// Processes the queue of effects that have been notified
/// of changes, running each effect function and clearing
/// the queue. This ensures all side effects are synchronized
/// with the current reactive state.
///
/// Called automatically when a batch completes or can be
/// called manually to force immediate effect execution.
@pragma('vm:align-loops')
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
void flush() {
  while (queuedEffects != null) {
    final effect = queuedEffects as EffectNode;
    if ((queuedEffects = effect.nextEffect) != null) {
      effect.nextEffect = null;
    } else {
      queuedEffectsTail = null;
    }
    run(effect);
  }
}

/// Stops a reactive node and removes it from the reactive system.
///
/// Clears all dependencies and subscribers of the node,
/// effectively removing it from the dependency graph.
/// After calling this, the node will no longer respond
/// to or trigger reactive updates.
///
/// This is essential for cleanup to prevent memory leaks.
void stop(ReactiveNode node) {
  node.depsTail = null;
  node.flags = ReactiveFlags.none;
  purgeDeps(node);
  final subs = node.subs;
  if (subs != null) {
    unlink(subs, subs.sub);
  }
}

/// Removes all stale dependencies from a subscriber node.
///
/// Called after a reactive computation completes to remove
/// dependencies that were not accessed in the latest run.
/// This keeps the dependency graph clean and prevents
/// unnecessary updates from old dependencies.
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
