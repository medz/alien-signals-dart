import 'system.dart';

class _EffectScope with Subscriber {
  @override
  int flags = SubscriberFlags.effect;
}

class _Effect with Dependency, Subscriber {
  _Effect(this.run);

  final void Function() run;

  @override
  int flags = SubscriberFlags.effect;
}

class _Signal<T> with Dependency {
  _Signal(this.currentValue);

  T currentValue;
}

class _Computed<T> extends _Signal<T?> with Subscriber {
  _Computed(this.getter) : super(null);

  final T Function(T? previousValue) getter;

  @override
  int flags = SubscriberFlags.computed | SubscriberFlags.dirty;

  bool update() {
    final oldValue = currentValue;
    final newValue = getter(oldValue);
    if (oldValue != newValue) {
      currentValue = newValue;
      return true;
    }

    return false;
  }
}

final _system = createReactiveSystem<_Computed>(
  updateComputed: (system, _Computed computed) {
    final prevSub = _activeSub;
    _activeSub = computed;
    system.startTracking(computed);
    try {
      return computed.update();
    } finally {
      _activeSub = prevSub;
      system.endTracking(computed);
    }
  },
  notifyEffect: (system, effect) {
    final flags = effect.flags;
    if (effect is _EffectScope) {
      if ((flags & SubscriberFlags.pendingEffect) != 0) {
        system.processPendingInnerEffects(effect, flags);
        return true;
      }

      return false;
    }

    if ((flags & SubscriberFlags.dirty) != 0 ||
        ((flags & SubscriberFlags.pendingComputed) != 0 &&
            system.updateDirtyFlag(effect, flags))) {
      final prevSub = _activeSub;
      _activeSub = effect;
      system.startTracking(effect);
      try {
        (effect as _Effect).run();
      } finally {
        _activeSub = prevSub;
        system.endTracking(effect);
      }
    } else {
      system.processPendingInnerEffects(effect, effect.flags);
    }

    return true;
  },
);

final _pauseStack = <Subscriber?>[];
int _batchDepth = 0;
Subscriber? _activeSub;
_EffectScope? _activeScope;

void startBatch() => ++_batchDepth;

void endBatch() {
  if ((--_batchDepth) == 0) {
    _system.processEffectNotifications();
  }
}

void pauseTracking() {
  _pauseStack.add(_activeSub);
  _activeSub = null;
}

void resumeTracking() {
  try {
    _activeSub = _pauseStack.removeLast();
  } catch (_) {
    _activeSub = null;
  }
}

T Function([T?, bool setNulls]) signal<T>(T value) {
  final signal = _Signal(value);
  return ([value, setNulls = false]) {
    if (value != null || (value == null && setNulls == true)) {
      if (signal.currentValue != (signal.currentValue = value as T)) {
        final subs = signal.subs;
        if (subs != null) {
          _system.propagate(subs);
          if (_batchDepth == 0) _system.processEffectNotifications();
        }
      }
    } else {
      if (_activeSub != null) {
        _system.link(signal, _activeSub!);
      }
    }

    return signal.currentValue;
  };
}

T Function() computed<T>(T Function(T? previousValue) getter) {
  final computed = _Computed(getter);
  return () {
    final flags = computed.flags;
    if ((flags & (SubscriberFlags.dirty | SubscriberFlags.pendingComputed)) !=
        0) {
      _system.processComputedUpdate(computed, flags);
    }

    if (_activeSub != null) {
      _system.link(computed, _activeSub!);
    } else if (_activeScope != null) {
      _system.link(computed, _activeScope!);
    }

    return computed.currentValue!;
  };
}

void Function() effect(void Function() run) {
  final effect = _Effect(run);

  if (_activeSub != null) {
    _system.link(effect, _activeSub!);
  } else if (_activeScope != null) {
    _system.link(effect, _activeScope!);
  }

  final prevSub = _activeSub;
  _activeSub = effect;
  try {
    run();
  } finally {
    _activeSub = prevSub;
  }

  return () {
    _system.startTracking(effect);
    _system.endTracking(effect);
  };
}

void Function() effectScope(void Function() run) {
  final scope = _EffectScope();
  final prevScope = _activeScope;
  _activeScope = scope;
  try {
    run();
  } finally {
    _activeScope = prevScope;
  }

  return () {
    _system.startTracking(scope);
    _system.endTracking(scope);
  };
}
