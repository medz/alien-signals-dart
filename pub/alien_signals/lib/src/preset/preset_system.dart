import 'package:alien_signals/alien_signals.dart';

import 'preset_types.dart';

final system = PresetSystem();

class PresetSystem extends ReactiveSystem<Computed> {
  Subscriber? activeSub;
  Subscriber? activeScope;
  int batchDepth = 0;
  final pauseStack = <Subscriber?>[];

  @override
  bool notifyEffect(Subscriber effect) {
    if (effect is EffectScope) {
      return notifyEffectScope(effect);
    }

    final flags = effect.flags;
    if ((flags & SubscriberFlags.dirty) != 0 ||
        ((flags & SubscriberFlags.pendingComputed) != 0 &&
            updateDirtyFlag(effect, flags))) {
      runEffect(effect as Effect);
    } else {
      processPendingInnerEffects(effect, effect.flags);
    }
    return true;
  }

  @override
  bool updateComputed(Computed computed) {
    final prevSub = activeSub;
    activeSub = computed;
    startTracking(computed);
    try {
      return computed.notify();
    } finally {
      activeSub = prevSub;
      endTracking(computed);
    }
  }

  void runEffect(Effect effect) {
    final prevSub = activeSub;
    activeSub = effect;
    startTracking(effect);
    try {
      effect.fn();
    } finally {
      activeSub = prevSub;
      endTracking(effect);
    }
  }

  void runEffectScope(EffectScope scope, void Function() fn) {
    final prevSub = activeScope;
    activeScope = scope;
    startTracking(scope);
    try {
      fn();
    } finally {
      activeScope = prevSub;
      endTracking(scope);
    }
  }

  bool notifyEffectScope(EffectScope scope) {
    final flags = scope.flags;
    if ((flags & SubscriberFlags.pendingEffect) != 0) {
      processPendingInnerEffects(scope, scope.flags);
      return true;
    }
    return false;
  }
}
