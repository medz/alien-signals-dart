import 'package:alien_signals/preset.dart';
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
    });

    expect(triggers, equals(1));
    count(2);
    expect(triggers, equals(2));
    stopScope();
    count(3);
    expect(triggers, equals(2));
  });
}
