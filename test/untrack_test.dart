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
        return s.value;
      } finally {
        setCurrentSub(currentSub);
      }
    });

    expect(c.value, 0);
    expect(computedTriggerTimes, 1);

    s.value = 1;
    s.value = 2;
    s.value = 3;
    expect(c.value, 0);
    expect(computedTriggerTimes, 1);
  });

  test("should pause tracking in effect", () {
    final a = signal(0);
    final b = signal(0);

    int effectTriggerTimes = 0;
    effect(() {
      effectTriggerTimes++;
      if (b.value > 0) {
        final currentSub = setCurrentSub(null);
        a.value;
        setCurrentSub(currentSub);
      }
    });

    expect(effectTriggerTimes, 1);

    b.value = 1;
    expect(effectTriggerTimes, 2);

    a.value = 1;
    a.value = 2;
    a.value = 3;
    expect(effectTriggerTimes, 2);

    b.value = 2;
    expect(effectTriggerTimes, 3);

    a.value = 4;
    a.value = 5;
    a.value = 6;
    expect(effectTriggerTimes, 3);

    b.value = 0;
    expect(effectTriggerTimes, 4);

    a.value = 7;
    a.value = 8;
    a.value = 9;
    expect(effectTriggerTimes, 4);
  });

  test("should pause tracking in effect scope", () {
    final s = signal(0);
    int effectTriggerTimes = 0;
    effectScope(() {
      effect(() {
        effectTriggerTimes++;
        final currentSub = setCurrentSub(null);
        s.value;
        setCurrentSub(currentSub);
      });
    });

    expect(effectTriggerTimes, 1);

    s.value = 1;
    s.value = 2;
    s.value = 3;
    expect(effectTriggerTimes, 1);
  });
}
