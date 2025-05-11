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
  bool update() {
    flags = ReactiveFlags.mutable;
    return previousValue != (previousValue = value);
  }
}

class PresetReactiveSystsm extends ReactiveSystem {
  const PresetReactiveSystsm();

  @override
  void notify(ReactiveNode sub) => notifyEffect(sub);

  @override
  void unwatched(ReactiveNode sub) {
    var toRemove = sub.deps;
    if (toRemove != null) {
      do {
        toRemove = unlink(toRemove!, sub);
      } while (toRemove != null);
      sub.flags |= ReactiveFlags.dirty;
    }
  }

  @override
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

ReactiveNode? getCurrentSub() => activeSub;
ReactiveNode? setCurrentSub(ReactiveNode? sub) {
  final prevSub = activeSub;
  activeSub = sub;
  return prevSub;
}

EffectScope? getCurrentScope() => activeScope;
EffectScope? setCurrentScope(EffectScope? scope) {
  final prevScope = activeScope;
  activeScope = scope;
  return prevScope;
}

void startBatch() => ++batchDepth;
void endBatch() {
  if ((--batchDepth) == 0) flush();
}

@Deprecated("Will be removed in the next major version. Use"
    "`const pausedSub = setCurrentSub(null)`"
    " instead for better performance.")
void pauseTracking() {
  pauseStack.add(setCurrentSub(null));
}

@Deprecated(
    "Will be removed in the next major version. Use `setCurrentSub(pausedSub)` instead for better performance.")
void resumeTracking() {
  try {
    setCurrentSub(pauseStack.removeLast());
  } catch (_) {
    setCurrentSub(null);
  }
}

T Function([T? value, bool nulls]) signal<T>(T initialValue) {
  final signal = Signal(
    value: initialValue,
    previousValue: initialValue,
    flags: ReactiveFlags.mutable,
  );

  return ([value, nulls = false]) => signalOper(signal, value, nulls);
}

T Function() computed<T>(T Function(T? previousValue) getter) {
  final computed = Computed(
    getter: getter,
    flags: ReactiveFlags.mutable | ReactiveFlags.dirty,
  );
  return () => computedOper(computed);
}

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

void flush() {
  while (notifyIndex < queuedEffectsLength) {
    final effect = queuedEffects[notifyIndex];
    queuedEffects[notifyIndex++] = null;
    run(effect!, effect.flags &= ~EffectFlags.queued);
  }
  notifyIndex = 0;
  queuedEffectsLength = 0;
}

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
