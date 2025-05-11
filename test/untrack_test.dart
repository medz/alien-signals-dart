import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test("should pause tracking in computed", () {
    final s = signal(0);
    int computedTriggerTimes = 0;

    final c = computed((_) {
      computedTriggerTimes++;
      final currentSub = setCurrentSub(null);
      try {
        return s();
      } finally {
        setCurrentSub(currentSub);
      }
    });

    expect(c(), 0);
    expect(computedTriggerTimes, 1);

    s(1);
    s(2);
    s(3);
    expect(c(), 0);
    expect(computedTriggerTimes, 1);
  });

  test("should pause tracking in effect", () {
    final a = signal(0);
    final b = signal(0);

    int effectTriggerTimes = 0;
    effect(() {
      effectTriggerTimes++;
      if (b() > 0) {
        final currentSub = setCurrentSub(null);
        a();
        setCurrentSub(currentSub);
      }
    });

    expect(effectTriggerTimes, 1);

    b(1);
    expect(effectTriggerTimes, 2);

    a(1);
    a(2);
    a(3);
    expect(effectTriggerTimes, 2);

    b(2);
    expect(effectTriggerTimes, 3);

    a(4);
    a(5);
    a(6);
    expect(effectTriggerTimes, 3);

    b(0);
    expect(effectTriggerTimes, 4);

    a(7);
    a(8);
    a(9);
    expect(effectTriggerTimes, 4);
  });

  test("should pause tracking in effect scope", () {
    final s = signal(0);
    int effectTriggerTimes = 0;
    effectScope(() {
      effect(() {
        effectTriggerTimes++;
        final currentSub = setCurrentSub(null);
        s();
        setCurrentSub(currentSub);
      });
    });

    expect(effectTriggerTimes, 1);

    s(1);
    s(2);
    s(3);
    expect(effectTriggerTimes, 1);
  });
}
