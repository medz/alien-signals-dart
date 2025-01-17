import 'package:alien_signals/preset.dart';

T batch<T>(T Function() fn) {
  startBatch();
  try {
    return fn();
  } finally {
    endBatch();
  }
}
