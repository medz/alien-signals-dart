import 'system.dart';

final system = PresetReactiveSystem();
final link = system.link,
    unlink = system.unlink,
    propagate = system.propagate,
    checkDirty = system.checkDirty,
    endTracking = system.endTracking,
    startTracking = system.startTracking,
    shallowPropagate = system.shallowPropagate;

int batchDepth = 0;
ReactiveNode? activeSub;
LinkedEffect? queuedEffects;
LinkedEffect? queuedEffectsTail;

abstract interface class LinkedEffect implements ReactiveNode {
  LinkedEffect? nextEffect;
}

/// A scope for effects that can be used to group and track multiple effects.
///
/// Effect scopes allow for collective disposal of effects and provide a way to
/// manage the lifecycle of related effects. When an effect scope is disposed,
/// all effects within that scope are automatically disposed as well.
abstract interface class EffectScope {
  void call();
}

class PresetEffectScope extends ReactiveNode
    implements LinkedEffect, EffectScope {
  PresetEffectScope({required super.flags});

  @override
  LinkedEffect? nextEffect;

  @override
  void call() => effectOper(this);
}

/// An effect that runs a function and automatically tracks its dependencies.
///
/// Effects are reactive computations that automatically track their dependencies
/// and re-run when those dependencies change. They are useful for side effects
/// like DOM updates, logging, or other imperative code that should react to
/// state changes.
///
/// The [run] function will be executed immediately when the effect is created,
/// and again whenever any of its tracked dependencies change.
abstract interface class Effect {
  void call();
}

class PresetEffect extends ReactiveNode implements LinkedEffect, Effect {
  PresetEffect({required super.flags, required this.callback});

  /// The function to execute when the effect runs.
  ///
  /// This function will be called:
  /// 1. Immediately when the effect is created
  /// 2. Whenever any of its tracked dependencies change
  final void Function() callback;

  @override
  LinkedEffect? nextEffect;

  @override
  void call() => effectOper(this);
}

abstract interface class Updatable {
  bool update();
}

abstract interface class Signal<T> {
  T get value;
}

abstract interface class WritableSignal<T> extends Signal<T> {
  set value(T value);
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

abstract interface class Computed<T> implements Signal<T> {}

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
    final prevSub = setCurrentSub(this);
    startTracking(this);
    try {
      final oldValue = cachedValue;
      return oldValue != (cachedValue = getter(oldValue));
    } finally {
      activeSub = prevSub;
      endTracking(this);
    }
  }
}

class PresetReactiveSystem extends ReactiveSystem {
  PresetReactiveSystem();

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
ReactiveNode? getCurrentSub() => activeSub;

/// Sets the currently active reactive subscription and returns the previous one.
///
/// This updates the [activeSub] to the provided [sub] and returns the previous
/// subscription that was active. This is used to manage the tracking context
/// during reactive operations.
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
ReactiveNode? setCurrentSub(ReactiveNode? sub) {
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
    flags: 17 /* Mutable | Dirty */,
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
  final effect = PresetEffect(callback: callback, flags: 2 /* Watching */);
  if (activeSub != null) {
    link(effect, activeSub!);
  }

  final prev = setCurrentSub(effect);
  try {
    callback();
    return effect;
  } finally {
    activeSub = prev;
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
  final scope = PresetEffectScope(flags: 0 /* None */);
  if (activeSub != null) {
    link(scope, activeSub!);
  }

  final prevSub = setCurrentSub(scope);
  try {
    callback();
    return scope;
  } finally {
    setCurrentSub(prevSub);
  }
}

/// Notifies an effect that it should be queued for execution.
///
/// This function marks an effect as queued if it hasn't been already. If the effect
/// has subscribers, it recursively notifies them. Otherwise, it adds the effect to
/// the queue of effects to be executed during the next flush cycle.
///
/// The [e] parameter is the reactive node (typically an Effect) to be notified.
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
      ((flags & 32 /* Pending */) != 0 && checkDirty(e.deps!, e))) {
    final prev = setCurrentSub(e);
    startTracking(e);
    try {
      (e as PresetEffect).callback();
    } finally {
      activeSub = prev;
      endTracking(e);
    }
    return;
  } else if ((flags & 32 /* Pending */) != 0) {
    e.flags = flags & -33 /* ~ReactiveFlags.pending */;
  }
  var link = e.deps;
  while (link != null) {
    final dep = link.dep;
    final depFlags = dep.flags;
    if ((depFlags & 64 /* Queued */) != 0) {
      run(dep, dep.flags = depFlags & -65 /* ~Queued */);
    }
    link = link.nextDep;
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
          checkDirty(computed.deps!, computed))) {
    if (computed.update()) {
      final subs = computed.subs;
      if (subs != null) {
        shallowPropagate(subs);
      }
    }
  } else if ((flags & 32 /* Pending */) != 0) {
    computed.flags = flags & -33 /* ~Pending */;
  }
  if (activeSub != null) {
    link(computed, activeSub!);
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
      link(signal, sub);
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
