import '_system.dart';

void startBatch() {
  system.batchDepth++;
}

void endBatch() {
  if (--system.batchDepth > 0) return;
  system.processEffectNotifications();
}

T batch<T>(T Function() run) {
  try {
    startBatch();
    return run();
  } finally {
    endBatch();
  }
}
