import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test('should correctly propagate changes through computed signals', () {
    final src = signal(0);
    final c1 = computed((_) => src() % 2);
    final c2 = computed((_) => c1());
    final c3 = computed((_) => c2());

    c3();
    src(1); // c1 -> dirty, c2 -> toCheckDirty, c3 -> toCheckDirty
    c2(); // c1 -> none, c2 -> none
    src(3); // c1 -> dirty, c2 -> toCheckDirty

    expect(c3(), 1);
  });

  test('should propagate updated source value through chained computations',
      () {
    final src = signal(0);
    final a = computed((_) => src());
    final b = computed((_) => a() % 2);
    final c = computed((_) => src());
    final d = computed((_) => b() + c());

    expect(d(), 0);
    src(2);
    expect(d(), 2);
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

    expect(d(), false);
    a(true);
    expect(d(), true);
  });

  test('should not update if the signal value is reverted', () {
    int times = 0;

    final src = signal(0);
    final c1 = computed((_) {
      times++;
      return src();
    });
    c1();
    expect(times, 1);
    src(1);
    src(0);
    c1();
    expect(times, 1);
  });
}
