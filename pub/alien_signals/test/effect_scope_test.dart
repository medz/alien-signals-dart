import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

main() {
  test('should not trigger after stop', () {
    final count = signal(0);
    final scope = effectScope();

    int triggers = 0;
    scope.run(() {
      effect(() {
        triggers++;
        count.get();
      });
    });

    expect(triggers, equals(1));

    count.set(2);
    expect(triggers, equals(2));

    scope.stop();
    count.set(3);
    expect(triggers, equals(2));
  });
}
