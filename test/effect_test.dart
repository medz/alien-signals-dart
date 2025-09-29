import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test("should clear subscriptions when untracked by all subscribers", () {
    int bRunTimes = 0;
    final a = signal(1);
    final b = computed((_) {
      bRunTimes++;
      return a.value * 2;
    });
    final stop = effect(() => b.value);

    expect(bRunTimes, 1);
    a.value = 2;
    expect(bRunTimes, 2);
    stop();
    a.value = 3;
    expect(bRunTimes, 2);
  });

  test("should not run untracked inner effect", () {
    final a = signal(3);
    final b = computed((_) => a.value > 0);

    effect(() {
      if (b.value) {
        effect(() {
          if (a.value == 0) throw Error();
        });
      }
    });

    a.value = 2;
    a.value = 1;
    a.value = 0;
  });

  test("should run outer effect first", () {
    final a = signal(1);
    final b = signal(1);

    effect(() {
      if (a.value > 0) {
        effect(() {
          b.value;
          if (a.value == 0) throw Error();
        });
      }
    });

    startBatch();
    b.value = 0;
    a.value = 0;
    endBatch();
  });

  test("should not trigger inner effect when resolve maybe dirty", () {
    final a = signal(0);
    final b = computed((_) => a.value % 2);
    int innerTriggerTimes = 0;
    effect(() {
      effect(() {
        b.value;
        innerTriggerTimes++;
        if (innerTriggerTimes >= 2) throw Error();
      });
    });

    a.value = 2;
  });

  test("should trigger inner effects in sequence", () {
    final a = signal(0);
    final b = signal(0);
    final c = computed((_) => a.value - b.value);
    final order = <String>[];

    effect(() {
      c.value;

      effect(() {
        order.add("first inner");
        a.value;
      });

      effect(() {
        order.add("last inner");
        a.value;
        b.value;
      });
    });

    order.length = 0;
    startBatch();
    a.value = 1;
    b.value = 1;
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
        a.value;
      });

      effect(() {
        order.add("last inner");
        a.value;
        b.value;
      });
    });

    order.length = 0;
    startBatch();
    a.value = 1;
    b.value = 1;
    endBatch();

    expect(order, ["first inner", "last inner"]);
  });

  test("should custom effect support batch", () {
    void Function() batchEffect(void Function() fn) {
      return effect(() {
        startBatch();
        try {
          fn();
        } finally {
          endBatch();
        }
      }).call;
    }

    final logs = <String>[];
    final a = signal(0);
    final b = signal(0);

    final aa = computed<void>((_) {
      logs.add('aa-0');
      if (a.value == 0) b.value = 1;
      logs.add('aa-1');
    });

    final bb = computed((_) {
      logs.add("bb");
      return b.value;
    });

    batchEffect(() => bb.value);
    batchEffect(() => aa.value);

    expect(logs, ["bb", "aa-0", "aa-1", "bb"]);
  });

  test("should duplicate subscribers do not affect the notify order", () {
    final s1 = signal(0);
    final s2 = signal(0);
    final order = <String>[];

    effect(() {
      order.add("a");
      final currentSub = setCurrentSub(null);
      final isOne = s2.value == 1;
      setCurrentSub(currentSub);
      if (isOne) s1.value;
      s2.value;
      s1.value;
    });

    effect(() {
      order.add("b");
      s1.value;
    });

    s2.value = 1;
    order.length = 0;
    s1.value += 1;
    expect(order, ["a", "b"]);
  });

  test("should handle side effect with inner effects", () {
    bool run = false;
    final a = signal(0);
    final b = signal(0);
    final order = <String>[];

    effect(() {
      effect(() {
        a.value;
        order.add("a");
      });
      effect(() {
        b.value;
        order.add("b");
      });

      expect(order, ["a", "b"]);

      order.length = 0;
      b.value = 1;
      a.value = 1;
      expect(order, ["b", "a"]);
      run = true;
    });

    expect(run, true);
  });

  test("should handle flags are indirectly updated during checkDirty", () {
    final a = signal(false);
    final b = computed((_) => a.value);
    final c = computed((_) {
      b.value;
      return 0;
    });
    final d = computed((_) {
      c.value;
      return b.value;
    });

    int triggers = 0;
    effect(() {
      d.value;
      triggers++;
    });
    expect(triggers, 1);
    a.value = true;
    expect(triggers, 2);
  });
}
