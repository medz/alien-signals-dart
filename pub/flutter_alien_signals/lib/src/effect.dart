import 'package:alien_signals/alien_signals.dart' as alien;

import '_internal/callonce.dart';
import '_internal/signals_element.dart';

alien.Effect<T> effect<T>(T Function() fn) {
  if (currentElement == null) {
    return alien.effect(fn);
  }

  final element = currentElement!, subs = element.subs;
  try {
    return callonce(
      factory: () => alien.effect(fn),
      container: subs,
      index: element.subCounter,
    );
  } finally {
    element.subCounter++;
  }
}
