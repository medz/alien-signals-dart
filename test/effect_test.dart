import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test("should clear subscriptions when untracked by all subscribers", () {
    int bRunTimes = 0;
    final a = signal(1);
    final b = computed((_) {
      bRunTimes++;
      return a() * 2;
    });
    final Effect(:dispose) = effect(() => b());

    expect(bRunTimes, 1);

    a(2);
    expect(bRunTimes, 2);

    dispose();
    a(3);
    expect(bRunTimes, 2);
  });

  test("should not run untracked inner effect", () {
    final a = signal(3);
    final b = computed((_) => a() > 0);

    effect(() {
      if (b()) {
        effect(() {
          if (a() == 0) throw Error();
        });
      }
    });

    a(2);
    a(1);
    a(0);
  });

  test("should run outer effect first", () {
    final a = signal(1);
    final b = signal(1);

    effect(() {
      if (a() > 0) {
        effect(() {
          b();
          if (a() == 0) throw Error();
        });
      }
    });

    startBatch();
    b(0);
    a(0);
    endBatch();
  });

  test("should not trigger inner effect when resolve maybe dirty", () {
    final a = signal(0);
    final b = computed((_) => a() % 2);
    int innerTriggerTimes = 0;
    effect(() {
      effect(() {
        b();
        innerTriggerTimes++;
        if (innerTriggerTimes >= 2) throw Error();
      });
    });

    a(2);
  });

  test("should trigger inner effects in sequence", () {
    final a = signal(0);
    final b = signal(0);
    final c = computed((_) => a() - b());
    final order = <String>[];

    effect(() {
      c();

      effect(() {
        order.add("first inner");
        a();
      });

      effect(() {
        order.add("last inner");
        a();
        b();
      });
    });

    order.length = 0;
    startBatch();
    a(1);
    b(1);
    endBatch();

    expect(order, ["first inner", "last inner"]);
  });

  test("should trigger inner effects in sequence in effect scope", () {
    final a = signal(0);
    final b = signal(0);
    final order = <String>[];

    effectScope(() {
      effect(() {
        order.add("first inner");
        a();
      });

      effect(() {
        order.add("last inner");
        a();
        b();
      });
    });

    order.length = 0;
    startBatch();
    a(1);
    b(1);
    endBatch();

    expect(order, ["first inner", "last inner"]);
  });

  test("should custom effect support batch", () {
    void batchEffect(void Function() fn) {
      effect(() {
        startBatch();
        try {
          fn();
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
      if (a() == 0) b(1);
      logs.add('aa-1');
    });

    final bb = computed((_) {
      logs.add("bb");
      return b();
    });

    batchEffect(() => bb());
    batchEffect(() => aa());

    expect(logs, ["bb", "aa-0", "aa-1", "bb"]);
  });

  test("should duplicate subscribers do not affect the notify order", () {
    final s1 = signal(0);
    final s2 = signal(0);
    final order = <String>[];

    effect(() {
      order.add("a");
      final currentSub = setActiveSub(null);
      final isOne = s2() == 1;
      setActiveSub(currentSub);
      if (isOne) s1();
      s2();
      s1();
    });

    effect(() {
      order.add("b");
      s1();
    });

    s2(1);
    order.length = 0;
    s1(s1() + 1);
    expect(order, ["a", "b"]);
  });

  test("should handle side effect with inner effects", () {
    bool run = false;
    final a = signal(0);
    final b = signal(0);
    final order = <String>[];

    effect(() {
      effect(() {
        a();
        order.add("a");
      });
      effect(() {
        b();
        order.add("b");
      });

      expect(order, ["a", "b"]);

      order.length = 0;
      b(1);
      a(1);
      expect(order, ["b", "a"]);
      run = true;
    });

    expect(run, true);
  });

  test("should handle flags are indirectly updated during checkDirty", () {
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
    a(true);
    expect(triggers, 2);
  });
}
