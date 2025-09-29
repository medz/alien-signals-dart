import 'system.dart';

/*------------------ Internal variables -------------------*/

const system = PresetReactiveSystem();
final link = system.link,
    unlink = system.unlink,
    propagate = system.propagate,
    checkDirty = system.checkDirty,
    shallowPropagate = system.shallowPropagate;

int cycle = 0;
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
  T get value;
}

/// A writable signal.
abstract interface class WritableSignal<T> extends Signal<T> {
  /// Sets the value of the signal.
  set value(T value);
}

/// A computed signal.
abstract interface class Computed<T> implements Signal<T> {}

/// A reactive effect.
abstract interface class Effect {
  /// Calls the effect on dispose.
  void call();
}

/// A reactive effect scope.
abstract interface class EffectScope {
  /// Calls the scope on dispose, notifying all effects.
  void call();
}

/*--------------------- Preset Impls ---------------------*/

abstract interface class Updatable {
  bool update();
}

class PresetWritableSignal<T> extends ReactiveNode
    implements Updatable, WritableSignal<T> {
  PresetWritableSignal({
    required super.flags,
    required T initialValue,
  })  : oldValue = initialValue,
        latestValue = initialValue;

  T oldValue;
  T latestValue;

  @override
  T get value => signalOper<T>(this, null, false);

  @override
  set value(T newValue) => signalOper<T>(this, newValue, true);

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool update() {
    flags = 1 /* Mutable */;
    return oldValue != (oldValue = latestValue);
  }
}

class PresetComputed<T> extends ReactiveNode implements Updatable, Computed<T> {
  PresetComputed({required super.flags, required this.getter});

  T? cachedValue;
  final T Function(T? previousValue) getter;

  @override
  T get value => computedOper(this);

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool update() {
    ++cycle;
    depsTail = null;
    flags = 5 /* Mutable | RecursedCheck */;

    final prevSub = setActiveSub(this);
    try {
      final oldValue = cachedValue;
      return oldValue != (cachedValue = getter(oldValue));
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

class PresetEffect extends ReactiveNode implements LinkedEffect, Effect {
  PresetEffect({required super.flags, required this.callback});

  final void Function() callback;

  @override
  LinkedEffect? nextEffect;

  @override
  void call() => effectOper(this);
}

class PresetEffectScope extends ReactiveNode
    implements LinkedEffect, EffectScope {
  PresetEffectScope({required super.flags});

  @override
  LinkedEffect? nextEffect;

  @override
  void call() => effectOper(this);
}

/*--------------------- Internal Impls ---------------------*/

class PresetReactiveSystem extends ReactiveSystem {
  const PresetReactiveSystem();

  @override
  void notify(ReactiveNode sub) => notifyEffect(sub);

  @override
  void unwatched(ReactiveNode node) {
    if (node is Computed) {
      var toRemove = node.deps;
      if (toRemove != null) {
        node.flags = 17 /* Mutable | Dirty */;
        do {
          toRemove = unlink(toRemove!, node);
        } while (toRemove != null);
      }
    } else if (node is! Signal) {
      effectOper(node);
    }
  }

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool update(ReactiveNode sub) {
    assert(sub is Updatable);
    return (sub as Updatable).update();
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

T computedOper<T>(PresetComputed<T> computed) {
  final flags = computed.flags;
  if ((flags & 16 /* Dirty */) != 0 ||
      ((flags & 32 /* Pending */) != 0 &&
          (checkDirty(computed.deps!, computed) ||
              // Always false, infinity is a value that can never be reached
              (computed.flags = flags & -33 /* ~Pending */) ==
                  double.infinity))) {
    if (computed.update()) {
      final subs = computed.subs;
      if (subs != null) {
        shallowPropagate(subs);
      }
    }
  } else if (flags == 0) {
    computed.flags = 1 /* Mutable */;
    final prevSub = setActiveSub(computed);
    try {
      computed.cachedValue = computed.getter(null);
    } finally {
      activeSub = prevSub;
    }
  }

  final sub = activeSub;
  if (sub != null) {
    link(computed, sub, cycle);
  }

  return computed.cachedValue as T;
}

T signalOper<T>(PresetWritableSignal<T> signal, T? newValue, bool update) {
  if (newValue is T && (newValue != null || (newValue == null && update))) {
    if (signal.latestValue != (signal.latestValue = newValue)) {
      signal.flags = 17 /* Mutable | Dirty */;
      final subs = signal.subs;
      if (subs != null) {
        propagate(subs);
        if (batchDepth == 0) flush();
      }
    }

    return newValue;
  }

  if ((signal.flags & 16 /* Dirty */) != 0) {
    if (signal.update()) {
      final subs = signal.subs;
      if (subs != null) {
        shallowPropagate(subs);
      }
    }
  }

  ReactiveNode? sub = activeSub;
  while (sub != null) {
    if ((sub.flags & 3 /* Mutable | Watching */) != 0) {
      link(signal, sub, cycle);
      break;
    }

    sub = sub.subs?.sub;
  }

  return signal.latestValue;
}

void effectOper(ReactiveNode e) {
  assert(e is Effect || e is EffectScope);
  var dep = e.deps;
  while (dep != null) {
    dep = unlink(dep, e);
  }

  final sub = e.subs;
  if (sub != null) unlink(sub);
  e.flags = 0;
}

void purgeDeps(ReactiveNode sub) {
  final depsTail = sub.depsTail;
  Link? toRemove = depsTail != null ? depsTail.nextDep : sub.deps;
  while (toRemove != null) {
    toRemove = unlink(toRemove, sub);
  }
}
