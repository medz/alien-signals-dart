import 'package:alien_signals/alien_signals.dart';

T batch<T>(T Function() fn) {
  startBatch();
  try {
    return fn();
  } finally {
    endBatch();
  }
}
