import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test('effect should unsubscribe from stale dependencies when branches change',
      () {
    final useA = signal(true);
    final a = signal(0);
    final b = signal(0);
    int runs = 0;

    effect(() {
      runs++;
      if (useA()) {
        a();
      } else {
        b();
      }
    });

    expect(runs, 1);
    a.set(1);
    expect(runs, 2);

    useA.set(false);
    expect(runs, 3);

    a.set(2);
    expect(runs, 3, reason: 'stale dependency should not trigger');

    b.set(1);
    expect(runs, 4);

    useA.set(true);
    expect(runs, 5);

    b.set(2);
    expect(runs, 5, reason: 'stale dependency should not trigger');
  });

  test('effectScope stops nested scopes and effects', () {
    final count = signal(0);
    int outer = 0;
    int inner = 0;
    int leaf = 0;

    final stop = effectScope(() {
      effect(() {
        outer++;
        count();
      });
      effectScope(() {
        effect(() {
          inner++;
          count();
        });
        effectScope(() {
          effect(() {
            leaf++;
            count();
          });
        });
      });
    });

    expect(outer, 1);
    expect(inner, 1);
    expect(leaf, 1);

    count.set(1);
    expect(outer, 2);
    expect(inner, 2);
    expect(leaf, 2);

    stop();
    count.set(2);
    expect(outer, 2);
    expect(inner, 2);
    expect(leaf, 2);
  });
}
