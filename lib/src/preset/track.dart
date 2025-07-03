import '_system.dart';

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void Function() pauseTracking() {
  system.pauseStack.add(system.activeSub);
  system.activeSub = null;
  return resumeTracking;
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void resumeTracking() {
  try {
    system.activeSub = system.pauseStack.removeLast();
  } catch (_) {
    system.activeSub = null;
  }
}
