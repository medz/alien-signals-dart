import 'package:alien_signals/alien_signals.dart' as alien;

import '_internal/callonce.dart';
import '_internal/signals_element.dart';

alien.Signal<T> signal<T>(T value) {
  if (currentElement == null) {
    return alien.signal(value);
  }

  final element = currentElement!, signals = element.signals;
  try {
    return callonce(
      factory: () => alien.signal(value),
      container: signals,
      index: element.signalCounter,
    );
  } finally {
    element.signalCounter++;
  }
}