import '_system.dart';

void Function() pauseTracking() {
  system.pauseStack.add(system.activeSub);
  system.activeSub = null;
  return resumeTracking;
}

void resumeTracking() {
  try {
    system.activeSub = system.pauseStack.removeLast();
  } catch (_) {
    system.activeSub = null;
  }
}
