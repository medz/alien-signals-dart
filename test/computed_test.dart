import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test("should correctly propagate changes through computed signals", () {
    final s = signal(0);
    final c1 = computed((_) => s.value % 2);
    final c2 = computed((_) => c1.value);
    final c3 = computed((_) => c2.value);

    c3.value;
    s.value = 1;
    c2.value;
    s.value = 3;

    expect(c3.value, 1);
  });

  test("should propagate updated source value through chained computations",
      () {
    final s = signal(0);
    final a = computed((_) => s.value);
    final b = computed((_) => a.value % 2);
    final c = computed((_) => s.value);
    final d = computed((_) => b.value + c.value);

    expect(d.value, 0);
    s.value = 2;
    expect(d.value, 2);
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

    expect(d.value, false);
    a.value = true;
    expect(d.value, true);
  });

  test("should not update if the signal value is reverted", () {
    var times = 0;
    final s = signal(0);
    final c = computed((_) {
      times++;
      return s.value;
    });

    c.value;
    expect(times, 1);
    s.value = 1;
    s.value = 0;
    c.value;
    expect(times, 1);
  });
}
