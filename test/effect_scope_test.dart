import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test('should not trigger after stop', () {
    final count = signal(1);
    int triggers = 0;

    final stopScope = effectScope(() {
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
    stopScope();
    count(4);
    expect(triggers, 3);
  });

  test('should dispose inner effects if created in an effect', () {
    final source = signal(1);

    int triggers = 0;

    effect(() {
      final dispose = effectScope(() {
        effect(() {
          source();
          triggers++;
        });
      });
      expect(triggers, 1);

      source(2);
      expect(triggers, 2);
      dispose();
      source(3);
      expect(triggers, 2);
    });
  });

  test(
      'should track signal updates in an inner scope when accessed by an outer effect',
      () {
    final source = signal(1);

    int triggers = 0;

    effect(() {
      effectScope(() {
        source();
      });
      triggers++;
    });

    expect(triggers, 1);
    source(2);
    expect(triggers, 2);
  });
}
