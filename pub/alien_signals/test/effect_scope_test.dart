import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

main() {
  test('should not trigger after stop', () {
    final count = signal(1);
    int triggers = 0;
    final stopScope = effectScope(() {
      effect(() {
        triggers++;
        count();
      });

      expect(triggers, equals(1));
      count(2);
      expect(triggers, equals(2));
    });

    count(3);
    expect(triggers, equals(3));
    stopScope();
    // count(4);
    // expect(triggers, equals(3));
  });
}
