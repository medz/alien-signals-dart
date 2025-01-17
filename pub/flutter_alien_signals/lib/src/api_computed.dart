import 'package:alien_signals/preset.dart' as alien;

import '_internal/callonce.dart';
import '_internal/signals_element.dart';

alien.Computed<T> computed<T>(T Function(T? oldValue) getter) {
  if (currentElement == null) {
    return alien.computed(getter);
  }

  final element = currentElement!, subs = element.subs;
  try {
    return callonce(
      factory: () => alien.computed(getter),
      container: subs,
      index: element.subCounter,
    );
  } finally {
    element.subCounter++;
  }
}
