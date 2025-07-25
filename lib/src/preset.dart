import 'system.dart';

abstract interface class LinkedEffect implements ReactiveNode {
  LinkedEffect? nextEffect;
}

/// A scope for effects that can be used to group and track multiple effects.
///
/// Effect scopes allow for collective disposal of effects and provide a way to
/// manage the lifecycle of related effects. When an effect scope is disposed,
/// all effects within that scope are automatically disposed as well.
class EffectScope extends ReactiveNode implements LinkedEffect {
  EffectScope({required super.flags});

  @override
  LinkedEffect? nextEffect;
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
class Effect extends ReactiveNode implements LinkedEffect {
  Effect({required super.flags, required this.run});

  /// The function to execute when the effect runs.
  ///
  /// This function will be called:
  /// 1. Immediately when the effect is created
  /// 2. Whenever any of its tracked dependencies change
  final void Function() run;

  @override
  LinkedEffect? nextEffect;
}

abstract interface class Updatable {
  bool update();
}

class Computed<T> extends ReactiveNode implements Updatable {
  Computed({required super.flags, required this.getter});

  T? value;
  final T Function(T? previousValue) getter;

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool update() {
    final prevSub = setCurrentSub(this);
    startTracking(this);
    try {
      final oldValue = value;
      final newValue = getter(oldValue);
      if (oldValue != newValue) {
        value = newValue;
        return true;
      }
      return false;
    } finally {
      activeSub = prevSub;
      endTracking(this);
    }
  }
}

class Signal<T> extends ReactiveNode implements Updatable {
  Signal({
    required super.flags,
    required this.value,
    required this.previousValue,
  });

  T previousValue;
  T value;

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool update() {
    flags = 1 /* Mutable */;
    final oldValue = previousValue;
    final newValue = value;
    if (oldValue != newValue) {
      previousValue = newValue;
      return true;
    }
    return false;
  }
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

/// The default reactive system instance that provides the core reactivity operations.
///
/// This constant provides access to the preset reactive system implementation
/// which handles signal propagation, effect scheduling, and dependency tracking.
const system = PresetReactiveSystem();

// Performance optimized flag constants
const int _FlagMutable = 1;
const int _FlagWatching = 2;
const int _FlagRecursedCheck = 4;
const int _FlagRecursed = 8;
const int _FlagDirty = 16;
const int _FlagPending = 32;
const int _FlagQueued = 64;

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
bool _hasFlag(int flags, int flag) => (flags & flag) != 0;

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
int _setFlag(int flags, int flag) => flags | flag;

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
int _clearFlag(int flags, int flag) => flags & ~flag;

final link = system.link,
    unlink = system.unlink,
    propagate = system.propagate,
    checkDirty = system.checkDirty,
    endTracking = system.endTracking,
    startTracking = system.startTracking,
    shallowPropagate = system.shallowPropagate;

int batchDepth = 0;
ReactiveNode? activeSub;
EffectScope? activeScope;
LinkedEffect? queuedEffects;
LinkedEffect? queuedEffectsTail;

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

/// Gets the currently active effect scope.
///
/// This returns the [EffectScope] that is currently being tracked as the active
/// scope during reactive operations. Returns null if no scope is currently active.
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
EffectScope? getCurrentScope() => activeScope;

/// Sets the currently active effect scope and returns the previous scope.
///
/// This updates the [activeScope] to the provided [scope] and returns the previous
/// scope that was active. This is used to manage the effect scope context
/// during reactive operations.
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
EffectScope? setCurrentScope(EffectScope? scope) {
  final prevScope = activeScope;
  activeScope = scope;
  return prevScope;
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
  final newDepth = --batchDepth;
  if (newDepth == 0 && queuedEffects != null) flush();
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
T Function([T? value, bool nulls]) signal<T>(T initialValue) {
  final signal = Signal(
    value: initialValue,
    previousValue: initialValue,
    flags: 1 /* Mutable */,
  );

  return ([value, nulls = false]) => signalOper(signal, value, nulls);
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
T Function() computed<T>(T Function(T? previousValue) getter) {
  final computed = Computed(
    getter: getter,
    flags: 17 /* Mutable | Dirty */,
  );
  return () => computedOper(computed);
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
void Function() effect(void Function() run) {
  final e = Effect(run: run, flags: 2 /* Watching */);
  if (activeSub != null) {
    link(e, activeSub!);
  } else if (activeScope != null) {
    link(e, activeScope!);
  }
  final prev = setCurrentSub(e);
  try {
    run();
  } finally {
    activeSub = prev;
  }

  return () => effectOper(e);
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
void Function() effectScope(void Function() run) {
  final e = EffectScope(flags: 0 /* None */);
  if (activeScope != null) link(e, activeScope!);

  final prevSub = setCurrentSub(null);
  final prevScope = setCurrentScope(e);

  try {
    run();
  } finally {
    setCurrentScope(prevScope);
    setCurrentSub(prevSub);
  }

  return () => effectOper(e);
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
  if (_hasFlag(flags, _FlagQueued)) return;
  
  e.flags = _setFlag(flags, _FlagQueued);
  final subs = e.subs;
  if (subs != null) {
    notifyEffect(subs.sub);
    return;
  }
  
  final tail = queuedEffectsTail;
  final linkedEffect = e as LinkedEffect;
  if (tail != null) {
    queuedEffectsTail = tail.nextEffect = linkedEffect;
  } else {
    queuedEffectsTail = queuedEffects = linkedEffect;
  }
}

void run(ReactiveNode e, int flags) {
  if ((flags & 16 /* Dirty */) != 0 ||
      ((flags & 32 /* Pending */) != 0 && checkDirty(e.deps!, e))) {
    final prev = setCurrentSub(e);
    startTracking(e);
    try {
      (e as Effect).run();
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
  var current = queuedEffects;
  if (current == null) return;
  
  queuedEffects = queuedEffectsTail = null;
  
  while (current != null) {
    final next = current.nextEffect;
    current.nextEffect = null;
    
    final flags = current.flags;
    current.flags = _clearFlag(flags, _FlagQueued);
    run(current, flags);
    
    current = next;
  }
}

T computedOper<T>(Computed<T> computed) {
  final flags = computed.flags;
  final isDirty = _hasFlag(flags, _FlagDirty);
  final isPending = _hasFlag(flags, _FlagPending);
  
  if (isDirty || (isPending && checkDirty(computed.deps!, computed))) {
    if (computed.update()) {
      final subs = computed.subs;
      if (subs != null) {
        shallowPropagate(subs);
      }
    }
  } else if (isPending) {
    computed.flags = _clearFlag(flags, _FlagPending);
  }
  
  final currentSub = activeSub;
  if (currentSub != null) {
    link(computed, currentSub);
  } else {
    final currentScope = activeScope;
    if (currentScope != null) {
      link(computed, currentScope);
    }
  }

  return computed.value as T;
}

T signalOper<T>(Signal<T> signal, T? value, bool nulls) {
  if (value is T && (value != null || (value == null && nulls))) {
    final currentValue = signal.value;
    if (currentValue != value) {
      signal.value = value;
      signal.flags = 17 /* Mutable | Dirty */;
      final subs = signal.subs;
      if (subs != null) {
        propagate(subs);
        if (batchDepth == 0) flush();
      }
    }

    return value;
  }

  final currentValue = signal.value;
  if (_hasFlag(signal.flags, _FlagDirty)) {
    if (signal.update()) {
      final subs = signal.subs;
      if (subs != null) {
        shallowPropagate(subs);
      }
    }
  }
  if (activeSub != null) {
    link(signal, activeSub!);
  }

  return currentValue;
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
