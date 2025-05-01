import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test("should not trigger after stop", () {
    int triggers = 0;
    final count = signal(0);
    final stop = effectScope(() {
      effect(() {
        triggers++;
        count();
      });

      expect(triggers, 1);
      count(2);
      expect(triggers, 2);
    });

    count(3);
    expect(triggers, 3);
    stop();
    count(4);
    expect(triggers, 3);
  });
}
