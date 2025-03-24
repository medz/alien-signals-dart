import 'package:alien_signals/alien_signals.dart';
import 'computed.dart';
import 'effect.dart';
import 'effect_scope.dart';

class PresetReactiveSystem extends ReactiveSystem<Computed> {
  late final pauseStack = <Subscriber?>[];
  int batchDepth = 0;
  Subscriber? activeSub;
  EffectScope? activeScope;

  @override
  bool notifyEffect(Subscriber effect) {
    final flags = effect.flags;
    if (effect is EffectScope) {
      if ((flags & SubscriberFlags.pendingEffect) != 0) {
        processPendingInnerEffects(effect, flags);
        return true;
      }
      return false;
    }

    // dart format off
    if (
      (flags & SubscriberFlags.dirty) != 0
      || (
        (flags & SubscriberFlags.pendingComputed) != 0
        && updateDirtyFlag(effect, flags)
      )
    ) {
      runEffect(effect as Effect);
    } else {
      processPendingInnerEffects(effect, flags);
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
      effect.run();
    } finally {
      activeSub = prevSub;
      endTracking(effect);
    }
  }
}

final system = PresetReactiveSystem();
