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

/// Creates a reactive signal with an initial value.
///
/// A signal is a reactive value container that notifies dependents when its
/// value changes. The returned function can be used to:
/// - Get the current value when called with no arguments
/// - Set a new value when called with a value argument
/// - Control whether null values should be treated as updates when [nulls] is true
///
/// Example:
/// ```dart
/// final count = signal(0);
/// count(); // get value
/// count(1); // set value
/// ```
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
WritableSignal<T> signal<T>(T initialValue) {
  return PresetWritableSignal(
      flags: 1 /* Mutable */, initialValue: initialValue);
}

/// Creates a reactive computed value that automatically tracks its dependencies.
///
/// A computed value is derived from other reactive values (signals or other computed values)
/// and automatically updates when its dependencies change. The [getter] function will be
/// called:
/// 1. Immediately when the computed is created
/// 2. Whenever any of its tracked dependencies change
///
/// The returned function can be called to get the current computed value.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// final doubled = computed(() => count() * 2);
/// doubled(); // returns 0
/// count(1);
/// doubled(); // returns 2
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

/// Creates a reactive effect that automatically tracks its dependencies and re-runs when they change.
///
/// An effect is a reactive computation that automatically tracks any reactive values (signals or computed values)
/// accessed during its execution. The effect will re-run whenever any of its tracked dependencies change.
///
/// The [run] function will be executed:
/// 1. Immediately when the effect is created
/// 2. Whenever any of its tracked dependencies change
///
/// Returns a cleanup function that can be called to dispose of the effect and stop tracking.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// effect(() => print('Count changed to ${count()}'));
/// // Prints: Count changed to 0
/// count(1);
/// // Prints: Count changed to 1
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

/// Creates a new effect scope that can be used to group and manage multiple effects.
///
/// An effect scope provides a way to collectively manage the lifecycle of effects.
/// When the scope is disposed by calling the returned cleanup function, all effects
/// created within the scope are automatically disposed as well.
///
/// The [run] function will be executed immediately within the new scope context.
/// Any effects created during this execution will be associated with this scope.
///
/// Returns a cleanup function that can be called to dispose of the scope and all
/// effects created within it.
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

abstract interface class Signal<T> {
  T get value;
}

abstract interface class WritableSignal<T> extends Signal<T> {
  set value(T value);
}

abstract interface class Computed<T> implements Signal<T> {}

abstract interface class Effect {
  void call();
}

abstract interface class EffectScope {
  void call();
}

/*--------------------- Preset Impls ---------------------*/

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

abstract interface class Updatable {
  bool update();
}

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
