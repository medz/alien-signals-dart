import 'dart:math' as math;

import 'package:alien_signals/alien_signals.dart';
import 'package:alien_signals/preset.dart';
import 'package:alien_signals/system.dart' show ReactiveFlags;
import 'package:test/test.dart';

void main() {
  test('should clear subscriptions when untracked by all subscribers', () {
    int bRunTimes = 0;

    final a = signal(1);
    final b = computed((_) {
      bRunTimes++;
      return a() * 2;
    });
    final stopEffect = effect(() {
      b();
    });

    expect(bRunTimes, 1);
    a.set(2);
    expect(bRunTimes, 2);
    stopEffect();
    a.set(3);
    expect(bRunTimes, 2);
  });

  test('should not run untracked inner effect', () {
    final a = signal(3);
    final b = computed((_) => a() > 0);

    effect(() {
      if (b()) {
        effect(() {
          if (a() == 0) {
            throw StateError('bad');
          }
        });
      }
    });

    a.set(2);
    a.set(1);
    a.set(0);
  });

  test('should run outer effect first', () {
    final a = signal(1);
    final b = signal(1);

    effect(() {
      if (a() != 0) {
        effect(() {
          b();
          if (a() == 0) {
            throw StateError("bad");
          }
        });
      }
    });

    startBatch();
    b.set(0);
    a.set(0);
    endBatch();
  });

  test('should not trigger inner effect when resolve maybe dirty', () {
    final a = signal(0);
    final b = computed((_) => a() % 2);

    int innerTriggerTimes = 0;

    effect(() {
      effect(() {
        b();
        innerTriggerTimes++;
        if (innerTriggerTimes >= 2) {
          throw StateError("bad");
        }
      });
    });

    a.set(2);
  });

  test('should notify inner effects in the same order as non-inner effects',
      () {
    final a = signal(0);
    final b = signal(0);
    final c = computed((_) => a() - b());
    final order1 = <String>[];
    final order2 = <String>[];
    final order3 = <String>[];

    effect(() {
      order1.add('effect1');
      a();
    });
    effect(() {
      order1.add('effect2');
      a();
      b();
    });

    effect(() {
      c();
      effect(() {
        order2.add('effect1');
        a();
      });
      effect(() {
        order2.add('effect2');
        a();
        b();
      });
    });

    effectScope(() {
      effect(() {
        order3.add('effect1');
        a();
      });
      effect(() {
        order3.add('effect2');
        a();
        b();
      });
    });

    order1.length = 0;
    order2.length = 0;
    order3.length = 0;

    startBatch();
    b.set(1);
    a.set(1);
    endBatch();

    expect(order1, ['effect2', 'effect1']);
    expect(order2, order1);
    expect(order3, order1);
  });

  test('should custom effect support batch', () {
    void batchEffect(void Function() fn) {
      effect(() {
        startBatch();
        try {
          return fn();
        } finally {
          endBatch();
        }
      });
    }

    final logs = <String>[];
    final a = signal(0);
    final b = signal(0);

    final aa = computed<void>((_) {
      logs.add('aa-0');
      if (a() == 0) {
        b.set(1);
      }
      logs.add('aa-1');
    });

    final bb = computed((_) {
      logs.add('bb');
      return b();
    });

    batchEffect(() {
      bb();
    });
    batchEffect(() {
      aa();
    });

    expect(logs, ['bb', 'aa-0', 'aa-1', 'bb']);
  });

  test('should duplicate subscribers do not affect the notify order', () {
    final src1 = signal(0);
    final src2 = signal(0);
    final order = <String>[];

    effect(() {
      order.add('a');
      final currentSub = setActiveSub();
      final isOne = src2() == 1;
      setActiveSub(currentSub);
      if (isOne) {
        src1();
      }
      src2();
      src1();
    });
    effect(() {
      order.add('b');
      src1();
    });
    src2.set(1); // src1.subs: a -> b -> a

    order.length = 0;
    src1.set(src1() + 1);

    expect(order, ['a', 'b']);
  });

  test('should handle side effect with inner effects', () {
    final a = signal(0);
    final b = signal(0);
    final order = <String>[];

    effect(() {
      effect(() {
        a();
        order.add('a');
      });
      effect(() {
        b();
        order.add('b');
      });
      expect(order, ['a', 'b']);

      order.length = 0;
      b.set(1);
      a.set(1);
      expect(order, ['b', 'a']);
    });
  });

  test(
      'should not execute skipped effects from previous failed flush when updating unrelated signal',
      () {
    final a = signal(0);
    final b = signal(0);
    final c = signal(0);
    final d = signal(0);
    final error = StateError('error');

    effect(() {
      if (a() == 1) {
        throw error;
      }
    });

    int bCalls = 0;
    effect(() {
      b();
      bCalls++;
    });

    int cCalls = 0;
    effect(() {
      c();
      cCalls++;
    });

    int dCalls = 0;
    effect(() {
      d();
      dCalls++;
    });

    startBatch();
    a.set(1);
    b.set(1);
    c.set(1);
    expect(() => endBatch(), throwsA(same(error)));

    expect(bCalls, 1);
    expect(cCalls, 1);

    d.set(1);

    expect(bCalls, 1);
    expect(cCalls, 1);
    expect(dCalls, 2);

    a.set(2);
    b.set(2);

    expect(bCalls, 2);
    expect(cCalls, 1);
  });

  test('should handle flags are indirectly updated during checkDirty', () {
    final a = signal(false);
    final b = computed((_) => a());
    final c = computed((_) {
      b();
      return 0;
    });
    final d = computed((_) {
      c();
      return b();
    });

    int triggers = 0;

    effect(() {
      d();
      triggers++;
    });
    expect(triggers, 1);
    a.set(true);
    expect(triggers, 2);
  });

  test('should handle effect recursion for the first execution', () {
    final src1 = signal(0);
    final src2 = signal(0);

    int triggers1 = 0;
    int triggers2 = 0;

    effect(() {
      triggers1++;
      src1.set(math.min(src1() + 1, 5));
    });
    effect(() {
      triggers2++;
      src2.set(math.min(src2() + 1, 5));
      src2();
    });

    expect(triggers1, 1);
    expect(triggers2, 1);
  });

  test('should support custom recurse effect', () {
    final src = signal(0);

    int triggers = 0;

    effect(() {
      getActiveSub()!.flags &= ~ReactiveFlags.recursedCheck;
      triggers++;
      src.set(math.min(src() + 1, 5));
    });

    expect(triggers, 6);
  });
}
