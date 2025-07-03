import 'system.dart';

extension type const EffectFlags._(int raw) implements ReactiveFlags {
  static const queued = EffectFlags._(1 << 6);
}

class EffectScope extends ReactiveNode {
  EffectScope({required super.flags});
}

class Effect extends ReactiveNode {
  Effect({required super.flags, required this.run});

  final void Function() run;
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
    flags = ReactiveFlags.mutable;
    return previousValue != (previousValue = value);
  }
}

class PresetReactiveSystsm extends ReactiveSystem {
  const PresetReactiveSystsm();

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void notify(ReactiveNode sub) => notifyEffect(sub);

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void unwatched(ReactiveNode node) {
    if (node is Computed) {
      var toRemove = node.deps;
      if (toRemove != null) {
        node.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
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

const system = PresetReactiveSystsm();
final link = system.link,
    unlink = system.unlink,
    propagate = system.propagate,
    checkDirty = system.checkDirty,
    endTracking = system.endTracking,
    startTracking = system.startTracking,
    shallowPropagate = system.shallowPropagate;

final pauseStack = <ReactiveNode?>[];
final queuedEffects = <int, ReactiveNode?>{};

int batchDepth = 0;
int notifyIndex = 0;
int queuedEffectsLength = 0;
ReactiveNode? activeSub;
EffectScope? activeScope;

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
ReactiveNode? getCurrentSub() => activeSub;

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
ReactiveNode? setCurrentSub(ReactiveNode? sub) {
  final prevSub = activeSub;
  activeSub = sub;
  return prevSub;
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
EffectScope? getCurrentScope() => activeScope;

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
EffectScope? setCurrentScope(EffectScope? scope) {
  final prevScope = activeScope;
  activeScope = scope;
  return prevScope;
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void startBatch() => ++batchDepth;

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void endBatch() {
  if ((--batchDepth) == 0) flush();
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
@Deprecated("Will be removed in the next major version. Use"
    "`const pausedSub = setCurrentSub(null)`"
    " instead for better performance.")
void pauseTracking() {
  pauseStack.add(setCurrentSub(null));
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
@Deprecated(
    "Will be removed in the next major version. Use `setCurrentSub(pausedSub)` instead for better performance.")
void resumeTracking() {
  try {
    setCurrentSub(pauseStack.removeLast());
  } catch (_) {
    setCurrentSub(null);
  }
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
T Function([T? value, bool nulls]) signal<T>(T initialValue) {
  final signal = Signal(
    value: initialValue,
    previousValue: initialValue,
    flags: ReactiveFlags.mutable,
  );

  return ([value, nulls = false]) => signalOper(signal, value, nulls);
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
T Function() computed<T>(T Function(T? previousValue) getter) {
  final computed = Computed(
    getter: getter,
    flags: ReactiveFlags.mutable | ReactiveFlags.dirty,
  );
  return () => computedOper(computed);
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void Function() effect(void Function() run) {
  final e = Effect(run: run, flags: ReactiveFlags.watching);
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

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void Function() effectScope(void Function() run) {
  final e = EffectScope(flags: ReactiveFlags.none);
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

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void notifyEffect(ReactiveNode e) {
  final flags = e.flags;
  if ((flags & EffectFlags.queued) == 0) {
    e.flags = flags | EffectFlags.queued;
    final subs = e.subs;
    if (subs != null) {
      notifyEffect(subs.sub);
    } else {
      queuedEffects[queuedEffectsLength++] = e;
    }
  }
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void run(ReactiveNode e, ReactiveFlags flags) {
  if ((flags & ReactiveFlags.dirty) != 0 ||
      ((flags & ReactiveFlags.pending) != 0 && checkDirty(e.deps!, e))) {
    final prev = setCurrentSub(e);
    startTracking(e);
    try {
      (e as Effect).run();
    } finally {
      activeSub = prev;
      endTracking(e);
    }
    return;
  } else if ((flags & ReactiveFlags.pending) != 0) {
    e.flags = flags & ~ReactiveFlags.pending;
  }
  var link = e.deps;
  while (link != null) {
    final dep = link.dep;
    final depFlags = dep.flags;
    if ((depFlags & EffectFlags.queued) != 0) {
      run(dep, dep.flags = depFlags & ~EffectFlags.queued);
    }
    link = link.nextDep;
  }
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void flush() {
  while (notifyIndex < queuedEffectsLength) {
    final effect = queuedEffects[notifyIndex];
    queuedEffects[notifyIndex++] = null;
    run(effect!, effect.flags &= ~EffectFlags.queued);
  }
  notifyIndex = 0;
  queuedEffectsLength = 0;
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
T computedOper<T>(Computed<T> computed) {
  final flags = computed.flags;
  if ((flags & ReactiveFlags.dirty) != 0 ||
      ((flags & ReactiveFlags.pending) != 0 &&
          checkDirty(computed.deps!, computed))) {
    if (computed.update()) {
      final subs = computed.subs;
      if (subs != null) {
        shallowPropagate(subs);
      }
    }
  } else if ((flags & ReactiveFlags.pending) != 0) {
    computed.flags = flags & ~ReactiveFlags.pending;
  }
  if (activeSub != null) {
    link(computed, activeSub!);
  } else if (activeScope != null) {
    link(computed, activeScope!);
  }

  return computed.value as T;
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
T signalOper<T>(Signal<T> signal, T? value, bool nulls) {
  if (value is T && (value != null || (value == null && nulls))) {
    if (signal.value != (signal.value = value)) {
      signal.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
      final subs = signal.subs;
      if (subs != null) {
        propagate(subs);
        if (batchDepth == 0) flush();
      }
    }

    return value;
  }

  value = signal.value;
  if ((signal.flags & ReactiveFlags.dirty) != 0) {
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

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void effectOper(ReactiveNode e) {
  assert(e is Effect || e is EffectScope);
  var dep = e.deps;
  while (dep != null) {
    dep = unlink(dep, e);
  }

  final sub = e.subs;
  if (sub != null) unlink(sub);

  e.flags = ReactiveFlags.none;
}
