import 'package:alien_signals/preset.dart' as alien;

import '_internal/callonce.dart';
import '_internal/signals_element.dart';

alien.EffectStop<alien.Effect> effect<T>(T Function() fn) {
  if (currentElement == null) {
    return alien.effect(fn);
  }

  final element = currentElement!, subs = element.subs;
  try {
    final effect = callonce(
      factory: () => alien.effect(fn).sub,
      container: subs,
      index: element.subCounter,
    );
    return alien.EffectStop(effect);
  } finally {
    element.subCounter++;
  }
}
