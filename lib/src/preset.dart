import 'package:alien_signals/system.dart';

/*------------------- Public variables --------------------*/
/// Alien signals preset system
const ReactiveSystem system = PresetReactiveSystem();
int cycle = 0;

/*------------------ Internal variables -------------------*/

final link = system.link,
    unlink = system.unlink,
    propagate = system.propagate,
    checkDirty = system.checkDirty,
    shallowPropagate = system.shallowPropagate;

int batchDepth = 0;
ReactiveNode? activeSub;
LinkedEffect? queuedEffects;
LinkedEffect? queuedEffectsTail;

/*----------------------- Public API -----------------------*/

/// Gets the current batch depth.
///
/// This returns the current batch depth, which is incremented when a batch
/// operation is started and decremented when it is completed.
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
int getBatchDepth() => batchDepth;

/// Gets the currently active reactive subscription.
///
/// This returns the [ReactiveNode] that is currently being tracked as the active
/// subscription during reactive operations. Returns null if no subscription
/// is currently active.
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
ReactiveNode? getActiveSub() => activeSub;

/// Sets the currently active reactive subscription and returns the previous one.
///
/// This updates the [activeSub] to the provided [sub] and returns the previous
/// subscription that was active. This is used to manage the tracking context
/// during reactive operations.
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
ReactiveNode? setActiveSub(ReactiveNode? sub) {
  final prevSub = activeSub;
  activeSub = sub;
  return prevSub;
}

/// Starts a new batch of reactive updates.
///
/// Increments the [batchDepth] counter to indicate that multiple reactive
/// updates should be batched together. While the batch depth is greater than 0,
/// updates will be queued but not immediately processed until [endBatch] is
/// called to decrease the batch depth back to 0.
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void startBatch() => ++batchDepth;

/// Ends the current batch of reactive updates and flushes pending effects if needed.
///
/// Decrements the [batchDepth] counter. If this brings the batch depth to 0,
/// any queued effects will be processed by calling [flush]. This ensures that
/// multiple updates made within a batch are processed together in a single
/// flush cycle.
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void endBatch() {
  if ((--batchDepth) == 0) flush();
}

/// A [WritableSignal] stores a value, and can be updated.
///
/// > When updated, its subscribers are notified.
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
WritableSignal<T> signal<T>(T initialValue) {
  return PresetWritableSignal(
      flags: 1 /* Mutable */, initialValue: initialValue);
}

/// A [Computed] derives a memoized value from other signals, and only re-computes
/// when those dependencies change.
///
/// ```dart
/// final source = signal(0);
/// final derived = computed((_) => source.value * 2);
///
/// print(derived.value); // Prints: 0
///
/// source.value = 1;
/// print(derived.value); // Prints: 2
/// ```
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
Computed<T> computed<T>(T Function(T? previousValue) getter) {
  return PresetComputed(
    flags: 0 /* None */,
    getter: getter,
  );
}

/// An [Effect] runs a function, and schedules it to re-run when the signals it
/// reads change.
///
/// ```dart
/// final count = signal(0);
/// final dispose = effect(() => print(count.value));
///
/// count.value++; // Prints: 1
/// count.value++; // Prints: 2
///
/// dispose();
/// count.value++; // Does't print anything
/// ```
Effect effect(void Function() callback) {
  final effect = PresetEffect(callback: callback, flags: 2 /* Watching */),
      prevSub = setActiveSub(effect);
  if (prevSub != null) {
    link(effect, prevSub, 0);
  }

  try {
    callback();
    return effect;
  } finally {
    activeSub = prevSub;
  }
}

/// An [EffectScope] groups effects allowing them to be disposed at the same time.
///
/// ```dart
/// final source = signal(0);
/// final dispose = effectScope(() {
///   effect(() => print(source.value));
///   effect(() => print(source.value));
/// });
///
/// source.value++; // Prints: 1, 1
/// dispose();
/// source.value++; // Does't print anything
/// ```
EffectScope effectScope(void Function() callback) {
  final scope = PresetEffectScope(flags: 0 /* None */),
      prevSub = setActiveSub(scope);
  if (prevSub != null) {
    link(scope, prevSub, 0);
  }

  try {
    callback();
    return scope;
  } finally {
    activeSub = prevSub;
  }
}

/*------------------------ Types def -----------------------*/

/// A readonly signal.
abstract interface class Signal<T> {
  /// Returns the current value of the signal.
  T call();
}

/// A writable signal.
abstract interface class WritableSignal<T> extends Signal<T> {
  /// Sets the value of the signal.
  @override
  T call([T? newValue, bool nulls]);
}

/// A computed signal.
abstract interface class Computed<T> implements Signal<T> {}

/// A reactive effect.
abstract interface class Effect {
  /// Calls the effect on dispose.
  void dispose();
}

/// A reactive effect scope.
abstract interface class EffectScope {
  /// Calls the scope on dispose, notifying all effects.
  void dispose();
}

/*--------------------- Preset Impls ---------------------*/

/// Preset writable signal implementation.
class PresetWritableSignal<T> extends ReactiveNode
    implements WritableSignal<T> {
  PresetWritableSignal({
    super.flags = 1 /* Mutable */,
    required T initialValue,
  })  : currentValue = initialValue,
        pendingValue = initialValue;

  T currentValue;
  T pendingValue;

  @override
  T call([T? newValue, bool nulls = false]) {
    if (newValue != null || (null is T && nulls)) {
      if (pendingValue != newValue) {
        pendingValue = newValue as T;
        flags = 17 /* Mutable | Dirty */;
        if (subs case final Link link) {
          propagate(link);
          if (batchDepth == 0) flush();
        }
      }

      return newValue as T;
    }

    /*----------------- getter 👇 ------------------------*/

    if ((flags & 16 /* Dirty */) != 0 && shouldUpdate()) {
      final subs = this.subs;
      if (subs != null) shallowPropagate(subs);
    }

    ReactiveNode? sub = activeSub;
    while (sub != null) {
      if ((sub.flags & 3 /* Mutable | Watching */) != 0) {
        link(this, sub, cycle);
        break;
      }

      sub = sub.subs?.sub;
    }

    return currentValue;
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool shouldUpdate() {
    flags = 1 /* Mutable */;
    return currentValue != (currentValue = pendingValue);
  }
}

/// Preset computed signal implementation.
class PresetComputed<T> extends ReactiveNode implements Computed<T> {
  PresetComputed({super.flags = 0 /* None */, required this.getter});

  T? currentValue;
  final T Function(T? previousValue) getter;

  @override
  T call() {
    final flags = this.flags;
    if ((flags & 16 /* Dirty */) != 0 ||
        ((flags & 32 /* Pending */) != 0 &&
            (checkDirty(deps!, this) ||
                // Always false, infinity is a value that can never be reached
                (this.flags = flags & -33 /* ~Pending */) ==
                    double.infinity))) {
      if (shouldUpdate()) {
        final subs = this.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    } else if (flags == 0 /* None */) {
      this.flags = 1 /* Mutable */;
      final prevSub = setActiveSub(this);
      try {
        currentValue = getter(null);
      } finally {
        activeSub = prevSub;
      }
    }

    final sub = activeSub;
    if (sub != null) {
      link(this, sub, cycle);
    }

    return currentValue as T;
  }

  bool shouldUpdate() {
    ++cycle;
    depsTail = null;
    flags = 5 /* Mutable | RecursedCheck */;

    final prevSub = setActiveSub(this);
    try {
      final oldValue = currentValue;
      return oldValue != (currentValue = getter(oldValue));
    } finally {
      activeSub = prevSub;
      flags &= -5 /* RecursedCheck */;
      purgeDeps(this);
    }
  }
}

abstract interface class LinkedEffect implements ReactiveNode {
  LinkedEffect? nextEffect;
}

/// Preset effect implementation.
class PresetEffect extends ReactiveNode implements LinkedEffect, Effect {
  PresetEffect({super.flags = 2 /* Watching */, required this.callback});

  final void Function() callback;

  @override
  LinkedEffect? nextEffect;

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void dispose() => effectOper(this);
}

/// Preset effect scope implementation.
class PresetEffectScope extends ReactiveNode
    implements LinkedEffect, EffectScope {
  PresetEffectScope({super.flags = 0 /* None */});

  @override
  LinkedEffect? nextEffect;

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void dispose() => effectOper(this);
}

/*--------------------- Internal Impls ---------------------*/

class PresetReactiveSystem extends ReactiveSystem {
  const PresetReactiveSystem();

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void notify(ReactiveNode sub) => notifyEffect(sub);

  @override
  void unwatched(ReactiveNode node) {
    if ((node.flags & 1 /* Mutable */) == 0) {
      effectOper(node);
    } else if (node.depsTail != null) {
      node.depsTail = null;
      node.flags = 17 /* Mutable | Dirty */;
      purgeDeps(node);
    }
  }

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool update(ReactiveNode sub) {
    return switch (sub) {
      PresetWritableSignal(:final shouldUpdate) => shouldUpdate(),
      PresetComputed(:final shouldUpdate) => shouldUpdate(),
      _ => false,
    };
  }
}

void notifyEffect(ReactiveNode e) {
  final flags = e.flags;
  if ((flags & 64 /* Queued */) == 0) {
    e.flags = flags | 64 /* Queued */;
    final subs = e.subs;
    if (subs != null) {
      notifyEffect(subs.sub);
    } else if (queuedEffectsTail != null) {
      queuedEffectsTail = queuedEffectsTail!.nextEffect = e as LinkedEffect;
    } else {
      queuedEffectsTail = queuedEffects = e as LinkedEffect;
    }
  }
}

void run(ReactiveNode e, int flags) {
  if ((flags & 16 /* Dirty */) != 0 ||
      ((flags & 32 /* Pending */) != 0 &&
          (checkDirty(e.deps!, e) ||
              // Always false, infinity is a value that can never be reached
              (e.flags = flags & -33 /* ~Pending */) == double.infinity))) {
    ++cycle;
    e.depsTail = null;
    e.flags = 6 /* Watching | RecursedCheck */;

    final prevSub = setActiveSub(e);
    try {
      (e as PresetEffect).callback();
    } finally {
      activeSub = prevSub;
      e.flags &= -5 /* ~RecursedCheck */;
      purgeDeps(e);
    }
  } else {
    Link? link = e.deps;
    while (link != null) {
      final dep = link.dep;
      final depFlags = dep.flags;
      if ((depFlags & 64 /* Queued */) != 0) {
        run(dep, dep.flags = depFlags & -65 /* ~Queued */);
      }
      link = link.nextDep;
    }
  }
}

void flush() {
  while (queuedEffects != null) {
    final effect = queuedEffects!;
    if ((queuedEffects = effect.nextEffect) != null) {
      effect.nextEffect = null;
    } else {
      queuedEffectsTail = null;
    }

    run(effect, effect.flags &= -65 /* ~Queued */);
  }
}

void effectOper(ReactiveNode e) {
  e.depsTail = null;
  e.flags = 0 /* None */;
  purgeDeps(e);

  final sub = e.subs;
  if (sub != null) unlink(sub);
}

void purgeDeps(ReactiveNode sub) {
  final depsTail = sub.depsTail;
  Link? dep = depsTail != null ? depsTail.nextDep : sub.deps;
  while (dep != null) {
    dep = unlink(dep, sub);
  }
}
