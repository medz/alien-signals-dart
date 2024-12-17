import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

main() {
  test('should clear subscriptions when untracked by all subscribers', () {
    int bRunTimes = 0;

    final a = signal(1);
    final b = computed((_) {
      bRunTimes++;
      return a.get() * 2;
    });
    final Effect(:stop) = effect(() => b.get());

    expect(bRunTimes, equals(1));

    a.set(2);
    expect(bRunTimes, equals(2));

    stop();
    a.set(2);
    expect(bRunTimes, equals(2));
  });

  test('should not run untracked inner effect', () {
    final a = signal(3);
    final b = computed((_) => a.get() > 0);

    effect(() {
      if (b.get()) {
        effect(() {
          if (a.get() == 0) {
            throw Error();
          }
        });
      }
    });

    a.value--;
    a.value--;
    a.value--;

    expect(b.get(), isFalse);
  });

  test('should run outer effect first', () {
    final a = signal(1);
    final b = signal(1);

    effect(() {
      if (a.get() > 0) {
        effect(() {
          b.get();
          if (a.get() == 0) {
            throw Error();
          }
        });
      }
    });

    startBatch();
    b.set(0);
    a.set(0);
    endBatch();
  });
}
