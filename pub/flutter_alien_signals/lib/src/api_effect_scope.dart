import 'package:alien_signals/alien_signals.dart' as alien;

import '_internal/callonce.dart';
import '_internal/signals_element.dart';

alien.EffectScope effectScope() {
  if (currentElement == null) {
    return alien.effectScope();
  }

  final element = currentElement!, subs = element.subs;
  try {
    return callonce(
      factory: alien.effectScope,
      container: subs,
      index: element.subCounter,
    );
  } finally {
    element.subCounter++;
  }
}
