export 'system.dart';

import 'system.dart';

abstract final class EffectScope implements ReactiveNode {}

extension type const _EffectFlags._(int raw) implements int {
  static const queued = _EffectFlags._(1 << 6);
}

final class _EffectScope extends ReactiveNode implements EffectScope {
  _EffectScope({required super.flags});
}

final class _Effect<T> extends ReactiveNode {
  _Effect({required super.flags, required this.fn});

  final T Function() fn;
}

final class _Computed<T> extends ReactiveNode {
  _Computed({required super.flags, required this.getter});

  T? value;
  T Function(T? previousValue) getter;

  bool update() {
    final prevSub = setCurrentSub(this);
    _system.startTracking(this);
    try {
      return value != (value = getter(value));
    } finally {
      setCurrentSub(prevSub);
      _system.endTracking(this);
    }
  }
}

final class _Signal<T> extends ReactiveNode {
  _Signal({
    required super.flags,
    required this.previousValue,
    required this.value,
  });

  T previousValue;
  T value;
}

class _PresetReactiveSystsm extends ReactiveSystem {
  final pauseStack = <ReactiveNode?>[];
  final queuedEffects = <ReactiveNode>[];

  int batchDepth = 0;
  ReactiveNode? activeSub;
  EffectScope? activeScope;

  @override
  void notify(ReactiveNode sub) {
    final flags = sub.flags;
    if ((flags & _EffectFlags.queued) == ReactiveFlags.none) {
      sub.flags = flags | _EffectFlags.queued;
      final subs = sub.subs;
      if (subs != null) {
        notify(subs.sub);
      } else {
        queuedEffects.add(sub);
      }
    }
  }

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
    assert(sub is _Signal || sub is _Computed);
    if (sub is _Computed) return sub.update();
    final signal = sub as _Signal;
    return signal.previousValue != (signal.previousValue = signal.value);
  }

  void flush() {
    for (final effect in queuedEffects) {
      run(effect, effect.flags &= ~_EffectFlags.queued);
    }
  }

  void run(ReactiveNode effect, ReactiveFlags flags) {
    if ((flags & ReactiveFlags.dirty) != ReactiveFlags.none ||
        ((flags & ReactiveFlags.pending) != ReactiveFlags.none &&
            checkDirty(effect.deps!, effect))) {
      final prev = setCurrentSub(effect);
      startTracking(effect);
      try {
        (effect as _Effect).fn();
      } finally {
        setCurrentSub(prev);
        endTracking(effect);
      }
    } else if ((flags & ReactiveFlags.pending) != ReactiveFlags.none) {
      effect.flags = flags & ~ReactiveFlags.pending;
    }

    var link = effect.deps;
    while (link != null) {
      final dep = link.dep;
      final depFlags = dep.flags;
      if ((depFlags & _EffectFlags.queued) != ReactiveFlags.none) {
        run(dep, dep.flags = depFlags & ~_EffectFlags.queued);
      }
      link = link.nextDep;
    }
  }
}

final _system = _PresetReactiveSystsm();

int get batchDepth => _system.batchDepth;
set batchDepth(int value) => _system.batchDepth = value;

ReactiveNode? getCurrentSub() => _system.activeSub;
ReactiveNode? setCurrentSub(ReactiveNode? sub) {
  final prevSub = _system.activeSub;
  _system.activeSub = sub;
  return prevSub;
}

EffectScope? getCurrentScope() => _system.activeScope;
EffectScope? setCurrentScope(EffectScope? scope) {
  final prevScope = _system.activeScope;
  _system.activeScope = scope;
  return prevScope;
}

void startBatch() => ++_system.batchDepth;
void endBatch() {
  if ((--_system.batchDepth) == 0) {
    _system.flush();
  }
}

void pauseTracking() {
  _system.pauseStack.add(_system.activeSub);
  _system.activeSub = null;
}

void resumeTracking() {
  try {
    _system.activeSub = _system.pauseStack.removeLast();
  } catch (_) {
    _system.activeSub = null;
  }
}

T Function([T? value, bool nulls]) signal<T>(T initialValue) {
  final signal = _Signal(
    value: initialValue,
    previousValue: initialValue,
    flags: ReactiveFlags.mutable,
  );
  return ([value, nulls = false]) {
    if (value is T && ((value == null && nulls) || value != null)) {
      if (signal.value != (signal.value = value)) {
        signal.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
        final subs = signal.subs;
        if (subs != null) {
          _system.propagate(subs);
          if (_system.batchDepth == 0) _system.flush();
        }
      }

      return value;
    }

    final result = signal.value;
    if ((signal.flags & ReactiveFlags.dirty) != ReactiveFlags.none) {
      signal.flags = ReactiveFlags.mutable;
      if (signal.previousValue != (signal.previousValue = result)) {
        final subs = signal.subs;
        if (subs != null) _system.shallowPropagate(subs);
      }
    }

    final activeSub = _system.activeSub;
    if (activeSub != null) _system.link(signal, activeSub);

    return result;
  };
}

T Function() computed<T>(T Function(T? previousValue) getter) {
  final computed = _Computed(
    getter: getter,
    flags: ReactiveFlags.mutable | ReactiveFlags.dirty,
  );
  return () {
    final flags = computed.flags;
    if ((flags & ReactiveFlags.dirty) != ReactiveFlags.none ||
        ((flags & ReactiveFlags.pending) != ReactiveFlags.none &&
            _system.checkDirty(computed.deps!, computed))) {
      if (_system.update(computed)) {
        final subs = computed.subs;
        if (subs != null) _system.shallowPropagate(subs);
      }
    } else if ((flags & ReactiveFlags.pending) != ReactiveFlags.none) {
      computed.flags = flags & ~ReactiveFlags.pending;
    }

    if (_system.activeSub != null) {
      _system.link(computed, _system.activeSub!);
    } else if (_system.activeScope != null) {
      _system.link(computed, _system.activeScope!);
    }

    return computed.value as T;
  };
}

void Function() effect<T>(T Function() fn) {
  final effect = _Effect(fn: fn, flags: ReactiveFlags.watching);
  if (_system.activeSub != null) {
    _system.link(effect, _system.activeSub!);
  } else if (_system.activeScope != null) {
    _system.link(effect, _system.activeScope!);
  }

  final prev = setCurrentSub(effect);
  try {
    effect.fn();
  } finally {
    setCurrentSub(prev);
  }

  return () => _effectStop(effect);
}

void Function() effectScope<T>(T Function() fn) {
  final scope = _EffectScope(flags: ReactiveFlags.none);
  if (_system.activeScope != null) {
    _system.link(scope, _system.activeScope!);
  }

  final prev = setCurrentScope(scope);
  try {
    fn();
  } finally {
    setCurrentScope(prev);
  }

  return () => _effectStop(scope);
}

void _effectStop(ReactiveNode effect) {
  var dep = effect.deps;
  while (dep != null) {
    dep = _system.unlink(dep, effect);
  }
  var sub = effect.subs;
  while (sub != null) {
    _system.unlink(sub, effect);
    sub = effect.subs;
  }
  effect.flags = ReactiveFlags.none;
}
