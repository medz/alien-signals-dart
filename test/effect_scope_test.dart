import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test("should not trigger after stop", () {
    int triggers = 0;
    final count = signal(0);
    final stop = effectScope(() {
      effect(() {
        triggers++;
        count.value;
      });

      expect(triggers, 1);
      count.value = 2;
      expect(triggers, 2);
    });

    count.value = 3;
    expect(triggers, 3);
    stop();
    count.value = 4;
    expect(triggers, 3);
  });

  test("should dispose inner effects if created in an effect", () {
    final s = signal(1);
    int triggers = 0;

    effect(() {
      final stop = effectScope(() {
        effect(() {
          s.value;
          triggers++;
        });
      });
      expect(triggers, 1);

      s.value = 2;
      expect(triggers, 2);

      stop();
      s.value = 3;
      expect(triggers, 2);
    });
  });

  test(
      'should track signal updates in an inner scope when accessed by an outer effect',
      () {
    final source = signal(0);
    int triggers = 0;
    effect(() {
      effectScope(() {
        source.value;
      });
      triggers++;
    });

    expect(triggers, equals(1));
    source.value = 2;
    expect(triggers, equals(2));
  });
}
