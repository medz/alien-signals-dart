import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test('should not trigger after stop', () {
    final count = signal(1);
    int triggers = 0;

    final stopScope = effectScope(() {
      effect(() {
        triggers++;
        count();
      });
      expect(triggers, 1);

      count.set(2);
      expect(triggers, 2);
    });

    count.set(3);
    expect(triggers, 3);
    stopScope();
    count.set(4);
    expect(triggers, 3);
  });

  test('should dispose inner effects if created in an effect', () {
    final source = signal(1);

    int triggers = 0;

    effect(() {
      final dispose = effectScope(() {
        effect(() {
          source();
          triggers++;
        });
      });
      expect(triggers, 1);

      source.set(2);
      expect(triggers, 2);
      dispose();
      source.set(3);
      expect(triggers, 2);
    });
  });

  test(
    'should track signal updates in an inner scope when accessed by an outer effect',
    () {
      final source = signal(1);

      int triggers = 0;

      effect(() {
        effectScope(() {
          source();
        });
        triggers++;
      });

      expect(triggers, 1);
      source.set(2);
      expect(triggers, 2);
    },
  );

  test('should propagate computed changes through nested scopes', () {
    final source = signal(0);
    final computedValue = computed((_) => source() * 2);
    int triggers = 0;

    effect(() {
      triggers++;
      effectScope(() {
        effectScope(() {
          source();
          computedValue();
        });
      });
    });

    expect(triggers, 1);

    source.set(1);
    expect(triggers, 2);

    trigger(() {
      computedValue();
    });
    expect(triggers, 3);
  });

  test('scope disposal cleans child effects in reverse dependency order', () {
    final log = <String>[];

    final stop = effectScope(() {
      effect(() {
        return () {
          log.add('first cleanup');
        };
      });
      effectScope(() {
        effect(() {
          return () {
            log.add('nested cleanup');
          };
        });
      });
      effect(() {
        return () {
          log.add('last cleanup');
        };
      });
    });

    stop();
    expect(log, ['last cleanup', 'nested cleanup', 'first cleanup']);
  });

  test('scope nested in effect cleans children before parent cleanup', () {
    final source = signal(0);
    final log = <String>[];

    effect(() {
      source();
      log.add('outer run');
      effectScope(() {
        effect(() {
          log.add('inner run');
          return () {
            log.add('inner cleanup');
          };
        });
      });
      return () {
        log.add('outer cleanup');
      };
    });

    log.clear();
    source.set(1);
    expect(log, ['inner cleanup', 'outer cleanup', 'outer run', 'inner run']);
  });
}
