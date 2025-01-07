import 'package:alien_signals/alien_signals.dart';

import '_internal/callonce.dart';
import '_internal/signals_element.dart';

Computed<T> computed<T>(T Function(T? oldValue) getter) {
  if (currentElement == null) {
    return Computed(getter);
  }

  final element = currentElement!, subs = element.subs;
  try {
    return callonce(
      factory: () => Computed(getter),
      container: subs,
      index: element.subCounter,
    );
  } finally {
    element.subCounter++;
  }
}
