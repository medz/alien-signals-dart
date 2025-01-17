import 'package:alien_signals/preset.dart' as alien;

import '_internal/callonce.dart';
import '_internal/signals_element.dart';

alien.EffectStop<alien.EffectScope> effectScope(void Function() fn) {
  if (currentElement == null) {
    return alien.effectScope(fn);
  }

  final element = currentElement!, subs = element.subs;
  try {
    final scope = callonce(
      factory: () => alien.effectScope(fn).sub,
      container: subs,
      index: element.subCounter,
    );
    return alien.EffectStop(scope);
  } finally {
    element.subCounter++;
  }
}
