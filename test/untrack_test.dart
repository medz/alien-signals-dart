import 'package:alien_signals/alien_signals.dart';
import 'package:alien_signals/preset.dart';
import 'package:test/test.dart';

void main() {
  test("should pause tracking in computed", () {
    final s = signal(0);
    int computedTriggerTimes = 0;

    final c = computed((_) {
      computedTriggerTimes++;
      final currentSub = setActiveSub(null);
      try {
        return s();
      } finally {
        setActiveSub(currentSub);
      }
    });

    expect(c(), 0);
    expect(computedTriggerTimes, 1);

    s.set(1);
    s.set(2);
    s.set(3);
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
        final currentSub = setActiveSub(null);
        a();
        setActiveSub(currentSub);
      }
    });

    expect(effectTriggerTimes, 1);

    b.set(1);
    expect(effectTriggerTimes, 2);

    a.set(1);
    a.set(2);
    a.set(3);
    expect(effectTriggerTimes, 2);

    b.set(2);
    expect(effectTriggerTimes, 3);

    a.set(4);
    a.set(5);
    a.set(6);
    expect(effectTriggerTimes, 3);

    b.set(0);
    expect(effectTriggerTimes, 4);

    a.set(7);
    a.set(8);
    a.set(9);
    expect(effectTriggerTimes, 4);
  });

  test("should pause tracking in effect scope", () {
    final s = signal(0);
    int effectTriggerTimes = 0;
    effectScope(() {
      effect(() {
        effectTriggerTimes++;
        final currentSub = setActiveSub(null);
        s();
        setActiveSub(currentSub);
      });
    });

    expect(effectTriggerTimes, 1);

    s.set(1);
    s.set(2);
    s.set(3);
    expect(effectTriggerTimes, 1);
  });
}
