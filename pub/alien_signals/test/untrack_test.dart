import 'package:alien_signals/preset.dart';
import 'package:test/test.dart';

main() {
  test('should pause tracking', () {
    final src = signal(0);
    final c = computed((_) {
      pauseTracking();
      final value = src();
      resumeTracking();
      return value;
    });
    expect(c(), equals(0));

    src(1);
    expect(c(), equals(0));
  });
}
