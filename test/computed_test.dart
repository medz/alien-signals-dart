import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test("should correctly propagate changes through computed signals", () {
    final s = signal(0);
    final c1 = computed((_) => s() % 2);
    final c2 = computed((_) => c1());
    final c3 = computed((_) => c2());

    c3();
    s(() => 1);
    c2();
    s(() => 3);

    expect(c3(), 1);
  });

  test("should propagate updated source value through chained computations",
      () {
    final s = signal(0);
    final a = computed((_) => s());
    final b = computed((_) => a() % 2);
    final c = computed((_) => s());
    final d = computed((_) => b() + c());

    expect(d(), 0);
    s(() => 2);
    expect(d(), 2);
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

    expect(d(), false);
    a(() => true);
    expect(d(), true);
  });

  test("should not update if the signal value is reverted", () {
    var times = 0;
    final s = signal(0);
    final c = computed((_) {
      times++;
      return s();
    });

    c();
    expect(times, 1);
    s(() => 1);
    s(() => 0);
    c();
    expect(times, 1);
  });
}
