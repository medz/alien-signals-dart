import '_system.dart';

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void startBatch() {
  system.batchDepth++;
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void endBatch() {
  if (--system.batchDepth == 0) {
    system.processEffectNotifications();
  }
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
T batch<T>(T Function() run) {
  startBatch();
  try {
    return run();
  } finally {
    endBatch();
  }
}
