import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

main() {
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

    expect(bRunTimes, equals(1));
    a(2);
    expect(bRunTimes, equals(2));
    stopEffect();
    a(3);
    expect(bRunTimes, equals(2));
  });

  test('should not run untracked inner effect', () {
    final a = signal(3);
    final b = computed((_) => a() > 0);

    effect(() {
      if (b()) {
        effect(() {
          if (a() == 0) {
            throw Error();
          }
        });
      }
    });

    void decrement() {
      a(a() - 1);
    }

    decrement();
    decrement();
    decrement();
  });

  test('should run outer effect first', () {
    final a = signal(1);
    final b = signal(1);

    effect(() {
      if (a() != 0) {
        effect(() {
          b();
          if (a() == 0) {
            throw Error();
          }
        });
      }
    });

    startBatch();
    b(0);
    a(0);
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
          throw Error();
        }
      });
    });

    a(2);
  });

  test('should trigger inner effects in sequence', () {
    final a = signal(0);
    final b = signal(0);
    final c = computed((_) => a() - b());
    final order = <String>[];

    effect(() {
      c();

      effect(() {
        order.add('first inner');
        a();
      });

      effect(() {
        order.add('last inner');
        a();
        b();
      });
    });

    order.length = 0;

    startBatch();
    b(1);
    a(1);
    endBatch();

    expect(order, ['first inner', 'last inner']);
  });

  test('should trigger inner effects in sequence in effect scope', () {
    final a = signal(0);
    final b = signal(0);
    final order = <String>[];

    effectScope(() {
      effect(() {
        order.add('first inner');
        a();
      });

      effect(() {
        order.add('last inner');
        a();
        b();
      });
    });

    order.length = 0;

    startBatch();
    b(1);
    a(1);
    endBatch();

    expect(order, ['first inner', 'last inner']);
  });

  test('should custom effect support batch', () {
    batchEffect(void Function() fn) {
      return effect(() {
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
        b(1);
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

  test("should duplicate subscribers do not affect the notify order", () {
    final src1 = signal(0);
    final src2 = signal(0);
    final order = <String>[];

    effect(() {
      order.add("a");
      pauseTracking();

      final isOne = src2() == 1;
      resumeTracking();

      if (isOne) {
        src1();
      }

      src2();
      src1();
    });

    effect(() {
      order.add("b");
      src1();
    });

    src2(1);
    expect(order, ["a", "b", "a"]);

    order.clear();
    src1(src1() + 1);
    expect(order, ['a', 'b']);
  });
}
