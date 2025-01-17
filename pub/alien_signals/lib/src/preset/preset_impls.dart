import 'package:alien_signals/alien_signals.dart';

import 'preset_effect_stop.dart';
import 'preset_system.dart';
import 'preset_types.dart';

void startBatch() {
  ++system.batchDepth;
}

void endBatch() {
  if ((--system.batchDepth) == 0) {
    system.processEffectNotifications();
  }
}

void pauseTracking() {
  system.pauseStack.add(system.activeSub);
  system.activeSub = null;
}

void resumeTracking() {
  try {
    system.activeSub = system.pauseStack.removeLast();
  } catch (_) {
    system.activeSub = null;
  }
}

WriteableSignal<T> signal<T>(T value) => _WriteableSignal(value);

class _WriteableSignal<T> with Dependency implements WriteableSignal<T> {
  _WriteableSignal(this.currentValue);

  @override
  T currentValue;

  @override
  T call([T? value]) {
    if (value is T) {
      if (currentValue != (currentValue = value)) {
        if (subs != null) {
          system.propagate(subs);
          if (system.batchDepth == 0) {
            system.processEffectNotifications();
          }
        }
      }

      return value;
    } else if (system.activeSub != null) {
      system.link(this, system.activeSub!);
    }

    return currentValue;
  }
}

Computed<T> computed<T>(T Function(T? oldValue) getter) => _Computed(getter);

class _Computed<T> with Dependency, Subscriber implements Computed<T> {
  _Computed(this.getter);

  final T Function(T? oldValue) getter;

  @override
  T? currentValue;

  @override
  int flags = SubscriberFlags.computed | SubscriberFlags.dirty;

  @override
  T call() {
    if ((flags & (SubscriberFlags.dirty | SubscriberFlags.pendingComputed)) !=
        0) {
      system.processComputedUpdate(this, flags);
    }
    if (system.activeSub != null) {
      system.link(this, system.activeSub!);
    } else if (system.activeScope != null) {
      system.link(this, system.activeScope!);
    }

    return currentValue as T;
  }

  @override
  bool notify() {
    final oldValue = currentValue;
    final newValue = getter(oldValue);
    if (oldValue != newValue) {
      currentValue = newValue;
      return true;
    }
    return false;
  }
}

EffectStop<Effect> effect(void Function() fn) {
  final effect = _Effect(fn);
  if (system.activeSub != null) {
    system.link(effect, system.activeSub!);
  } else if (system.activeScope != null) {
    system.link(effect, system.activeScope!);
  }
  system.runEffect(effect);
  return EffectStop(effect);
}

class _Effect with Dependency, Subscriber implements Effect {
  _Effect(this.fn);

  @override
  final void Function() fn;

  @override
  int flags = SubscriberFlags.effect;
}

EffectStop<EffectScope> effectScope(void Function() fn) {
  final scope = _EffectScope();
  system.runEffectScope(scope, fn);
  return EffectStop(scope);
}

class _EffectScope with Subscriber implements EffectScope {
  @override
  int flags = SubscriberFlags.effect;
}
