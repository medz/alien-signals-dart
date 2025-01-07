import 'package:alien_signals/alien_signals.dart';

import '_internal/callonce.dart';
import '_internal/signals_element.dart';

Signal<T> signal<T>(T value) {
  if (currentElement == null) {
    return Signal(value);
  }

  final element = currentElement!, signals = element.signals;
  try {
    return callonce(
      factory: () => Signal(value),
      container: signals,
      index: element.signalCounter,
    );
  } finally {
    element.signalCounter++;
  }
}
