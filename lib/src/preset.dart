import 'system.dart';
import 'performance_monitor.dart';

abstract interface class LinkedEffect implements ReactiveNode {
  LinkedEffect? nextEffect;
  
  /// Priority level for effect scheduling (higher values = higher priority)
  int get priority => 0;
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
  Effect({required super.flags, required this.run, this.priority = 0});

  /// The function to execute when the effect runs.
  ///
  /// This function will be called:
  /// 1. Immediately when the effect is created
  /// 2. Whenever any of its tracked dependencies change
  final void Function() run;
  
  /// Priority level for effect scheduling (higher values = higher priority)
  @override
  final int priority;

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
      return oldValue != (value = getter(oldValue));
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
    return previousValue != (previousValue = value);
  }
}

class PresetReactiveSystsm extends ReactiveSystem {
  const PresetReactiveSystsm();

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
const system = PresetReactiveSystsm();

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

/// Enhanced batching with deferred signal updates
List<Signal>? _batchedSignals;
List? _batchedValues;
int _batchedCount = 0;

/// Priority-based effect scheduling
LinkedEffect? _highPriorityEffects;
LinkedEffect? _highPriorityEffectsTail;
LinkedEffect? _normalPriorityEffects;
LinkedEffect? _normalPriorityEffectsTail;

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
  if ((--batchDepth) == 0) {
    _flushBatchedSignals();
    flush();
  }
}

/// Flushes all batched signal updates at once for better performance.
void _flushBatchedSignals() {
  if (_batchedCount > 0) {
    final signals = _batchedSignals!;
    final values = _batchedValues!;
    
    // Process all batched updates
    for (int i = 0; i < _batchedCount; i++) {
      final signal = signals[i];
      final value = values[i];
      
      if (signal.value != value) {
        signal.value = value;
        signal.flags = 17; // Mutable | Dirty
        final subs = signal.subs;
        if (subs != null) {
          propagate(subs);
        }
      }
    }
    
    // Clear batch
    _batchedCount = 0;
  }
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
/// The optional [priority] parameter allows controlling execution order during batch flushes.
/// Higher priority values execute first. Default is 0 (normal priority).
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
void Function() effect(void Function() run, {int priority = 0}) {
  final e = Effect(run: run, flags: 2 /* Watching */, priority: priority);
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
/// the appropriate priority queue for execution during the next flush cycle.
///
/// The [e] parameter is the reactive node (typically an Effect) to be notified.
void notifyEffect(ReactiveNode e) {
  final flags = e.flags;
  if ((flags & 64 /* Queued */) == 0) {
    e.flags = flags | 64 /* Queued */;
    final subs = e.subs;
    if (subs != null) {
      notifyEffect(subs.sub);
    } else {
      final linkedEffect = e as LinkedEffect;
      
      // Queue based on priority
      if (linkedEffect.priority > 0) {
        // High priority queue
        if (_highPriorityEffectsTail != null) {
          _highPriorityEffectsTail = _highPriorityEffectsTail!.nextEffect = linkedEffect;
        } else {
          _highPriorityEffectsTail = _highPriorityEffects = linkedEffect;
        }
      } else {
        // Normal priority queue
        if (_normalPriorityEffectsTail != null) {
          _normalPriorityEffectsTail = _normalPriorityEffectsTail!.nextEffect = linkedEffect;
        } else {
          _normalPriorityEffectsTail = _normalPriorityEffects = linkedEffect;
        }
      }
      
      // Maintain backward compatibility with original queue
      if (queuedEffectsTail != null) {
        queuedEffectsTail = queuedEffectsTail!.nextEffect = linkedEffect;
      } else {
        queuedEffectsTail = queuedEffects = linkedEffect;
      }
    }
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
  final stopwatch = Stopwatch()..start();
  
  // Process high priority effects first
  while (_highPriorityEffects != null) {
    performanceMonitor.recordHighPriorityEffect();
    final effect = _highPriorityEffects!;
    if ((_highPriorityEffects = effect.nextEffect) != null) {
      effect.nextEffect = null;
    } else {
      _highPriorityEffectsTail = null;
    }
    run(effect, effect.flags &= -65 /* ~Queued */);
  }
  
  // Then process normal priority effects
  while (_normalPriorityEffects != null) {
    performanceMonitor.recordNormalPriorityEffect();
    final effect = _normalPriorityEffects!;
    if ((_normalPriorityEffects = effect.nextEffect) != null) {
      effect.nextEffect = null;
    } else {
      _normalPriorityEffectsTail = null;
    }
    run(effect, effect.flags &= -65 /* ~Queued */);
  }
  
  // Maintain backward compatibility
  while (queuedEffects != null) {
    performanceMonitor.recordNormalPriorityEffect();
    final effect = queuedEffects!;
    if ((queuedEffects = effect.nextEffect) != null) {
      effect.nextEffect = null;
    } else {
      queuedEffectsTail = null;
    }
    run(effect, effect.flags &= -65 /* ~Queued */);
  }
  
  stopwatch.stop();
  performanceMonitor.recordFlushTime(stopwatch.elapsedMicroseconds);
}

T computedOper<T>(Computed<T> computed) {
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
  } else if (activeScope != null) {
    link(computed, activeScope!);
  }

  return computed.value as T;
}

T signalOper<T>(Signal<T> signal, T? value, bool nulls) {
  if (value is T && (value != null || (value == null && nulls))) {
    // Enhanced batching: defer updates when in batch mode
    if (batchDepth > 0) {
      // Initialize batch arrays if needed
      if (_batchedSignals == null) {
        _batchedSignals = <Signal>[];
        _batchedValues = <dynamic>[];
      }
      
      // Check if signal is already in batch
      bool found = false;
      for (int i = 0; i < _batchedCount; i++) {
        if (identical(_batchedSignals![i], signal)) {
          _batchedValues![i] = value;
          found = true;
          break;
        }
      }
      
      // Add to batch if not found
      if (!found) {
        performanceMonitor.recordBatchedUpdate();
        if (_batchedCount >= _batchedSignals!.length) {
          _batchedSignals!.add(signal);
          _batchedValues!.add(value);
        } else {
          _batchedSignals![_batchedCount] = signal;
          _batchedValues![_batchedCount] = value;
        }
        _batchedCount++;
      }
      
      return value;
    }
    
    // Immediate update when not batching
    performanceMonitor.recordImmediateUpdate();
    if (signal.value != (signal.value = value)) {
      signal.flags = 17 /* Mutable | Dirty */;
      final subs = signal.subs;
      if (subs != null) {
        propagate(subs);
        flush();
      }
    }

    return value;
  }

  value = signal.value;
  if ((signal.flags & 16 /* Dirty */) != 0) {
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

  return value;
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
