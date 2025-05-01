import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test("should pause tracking", () {
    final s = signal(0);
    final c = computed((_) {
      pauseTracking();
      try {
        return s();
      } finally {
        resumeTracking();
      }
    });

    expect(c(), 0);

    s(1);
    expect(c(), 0);
  });
}
