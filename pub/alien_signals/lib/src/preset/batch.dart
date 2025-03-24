import '_system.dart';

void startBatch() {
  system.batchDepth++;
}

void endBatch() {
  if (--system.batchDepth == 0) {
    system.processEffectNotifications();
  }
}

T batch<T>(T Function() run) {
  startBatch();
  try {
    return run();
  } finally {
    endBatch();
  }
}
