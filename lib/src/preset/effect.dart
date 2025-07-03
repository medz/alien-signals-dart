import 'package:alien_signals/alien_signals.dart';

import '_system.dart';
import 'types.dart' as types;

class Effect with Dependency, Subscriber implements types.Effect {
  Effect(this.run);

  @override
  int flags = SubscriberFlags.effect;

  @override
  final void Function() run;

  @override
  void call() {
    system.startTracking(this);
    system.endTracking(this);
  }
}

types.Effect effect(void Function() run) {
  final effect = Effect(run);
  if (system.activeSub != null) {
    system.link(effect, system.activeSub!);
  } else if (system.activeScope != null) {
    system.link(effect, system.activeScope!);
  }

  system.runEffect(effect);
  return effect;
}
