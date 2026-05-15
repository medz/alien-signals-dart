import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test('effect cleanup runs before re-run and on dispose', () {
    final source = signal(0);
    final log = <String>[];

    final stop = effect(() {
      final value = source();
      log.add('run $value');
      return () {
        log.add('cleanup $value');
      };
    });

    expect(log, ['run 0']);

    source.set(1);
    expect(log, ['run 0', 'cleanup 0', 'run 1']);

    stop();
    expect(log, ['run 0', 'cleanup 0', 'run 1', 'cleanup 1']);

    source.set(2);
    expect(log, ['run 0', 'cleanup 0', 'run 1', 'cleanup 1']);
  });

  test('effect cleanup reads are not tracked before re-run', () {
    final source = signal(0);
    final cleanupSource = signal(0);
    int runs = 0;
    int cleanups = 0;

    effect(() {
      source();
      runs++;
      return () {
        cleanupSource();
        cleanups++;
      };
    });

    expect(runs, 1);

    source.set(1);
    expect(runs, 2);
    expect(cleanups, 1);

    cleanupSource.set(1);
    expect(runs, 2);
    expect(cleanups, 1);
  });

  test('effect cleanup reads are not tracked on dispose', () {
    final cleanupSource = signal(0);
    int outerRuns = 0;
    int cleanups = 0;

    effect(() {
      outerRuns++;
      final stop = effect(() {
        return () {
          cleanupSource();
          cleanups++;
        };
      });
      stop();
    });

    expect(outerRuns, 1);
    expect(cleanups, 1);

    cleanupSource.set(1);
    expect(outerRuns, 1);
    expect(cleanups, 1);
  });

  test('effect cleanup can stop the effect before re-run', () {
    final source = signal(0);
    late Effect stop;
    int runs = 0;
    int cleanups = 0;

    stop = effect(() {
      source();
      runs++;
      return () {
        cleanups++;
        stop();
      };
    });

    expect(runs, 1);

    source.set(1);
    expect(cleanups, 1);
    expect(runs, 1);
  });

  test('nested effect cleanup runs before parent cleanup on re-run', () {
    final source = signal(0);
    final log = <String>[];

    effect(() {
      source();
      log.add('outer run');
      effect(() {
        log.add('inner run');
        return () {
          log.add('inner cleanup');
        };
      });
      return () {
        log.add('outer cleanup');
      };
    });

    expect(log, ['outer run', 'inner run']);

    log.clear();
    source.set(1);
    expect(log, ['inner cleanup', 'outer cleanup', 'outer run', 'inner run']);
  });

  test('effect disposal cleans children in reverse dependency order', () {
    final log = <String>[];

    final stop = effect(() {
      effect(() {
        effect(() {
          return () {
            log.add('grandchild cleanup');
          };
        });
        return () {
          log.add('child cleanup');
        };
      });
      effect(() {
        return () {
          log.add('sibling cleanup');
        };
      });
      return () {
        log.add('outer cleanup');
      };
    });

    stop();
    expect(log, [
      'sibling cleanup',
      'grandchild cleanup',
      'child cleanup',
      'outer cleanup',
    ]);
  });

  test(
    'computed refresh disposes child effects before running getter again',
    () {
      final source = signal(0);
      final log = <String>[];

      final value = computed((previous) {
        log.add('computed run');
        effect(() {
          log.add('inner run');
          return () {
            log.add('inner cleanup');
          };
        });
        return source();
      });

      effect(() {
        value();
      });

      expect(log, ['computed run', 'inner run']);

      log.clear();
      source.set(1);
      expect(log, ['inner cleanup', 'computed run', 'inner run']);
    },
  );

  test('computed disposal cleans child effects in reverse order', () {
    final log = <String>[];

    final value = computed((previous) {
      effect(() {
        return () {
          log.add('first cleanup');
        };
      });
      effect(() {
        return () {
          log.add('second cleanup');
        };
      });
      effect(() {
        return () {
          log.add('third cleanup');
        };
      });
      return 0;
    });

    final stop = effect(() {
      value();
    });

    log.clear();
    stop();
    expect(log, ['third cleanup', 'second cleanup', 'first cleanup']);
  });

  test('outer cleanup order survives an inner-only re-run', () {
    final outerSource = signal(0);
    final innerSource = signal(0);
    final log = <String>[];

    effect(() {
      outerSource();
      log.add('outer run');
      effect(() {
        innerSource();
        log.add('inner run');
        return () {
          log.add('inner cleanup');
        };
      });
      return () {
        log.add('outer cleanup');
      };
    });

    innerSource.set(1);
    log.clear();

    outerSource.set(1);
    expect(log, ['inner cleanup', 'outer cleanup', 'outer run', 'inner run']);
  });

  test(
    'effect should unsubscribe from stale dependencies when branches change',
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
    },
  );

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
