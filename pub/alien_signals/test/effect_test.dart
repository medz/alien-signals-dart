import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

import 'src/batch_effect.dart';

main() {
  test('should clear subscriptions when untracked by all subscribers', () {
    int bRunTimes = 0;

    final a = signal(1);
    final b = computed((_) {
      bRunTimes++;
      return a.get() * 2;
    });
    final Effect(:stop) = effect(() => b.get());

    expect(bRunTimes, equals(1));

    a.set(2);
    expect(bRunTimes, equals(2));

    stop();
    a.set(2);
    expect(bRunTimes, equals(2));
  });

  test('should not run untracked inner effect', () {
    final a = signal(3);
    final b = computed((_) => a.get() > 0);

    effect(() {
      if (b.get()) {
        effect(() {
          if (a.get() == 0) {
            throw Error();
          }
        });
      }
    });

    a.set(a.get() - 1);
    a.set(a.get() - 1);
    a.set(a.get() - 1);

    expect(b.get(), isFalse);
  });

  test('should run outer effect first', () {
    final a = signal(1);
    final b = signal(1);

    effect(() {
      if (a.get() > 0) {
        effect(() {
          b.get();
          if (a.get() == 0) {
            throw Error();
          }
        });
      }
    });

    startBatch();
    b.set(0);
    a.set(0);
    endBatch();
  });

  test('should custom effect support batch', () {
    final logs = <String>[];
    final a = signal(0);
    final b = signal(0);

    final aa = computed<void>((_) {
      logs.add('aa-0');
      if (a.get() == 0) {
        b.set(1);
      }
      logs.add('aa-1');
    });

    final bb = computed((_) {
      logs.add('bb');
      return b.get();
    });

    BatchEffect(() {
      bb.get();
    }).run();

    BatchEffect(() {
      aa.get();
    }).run();

    expect(logs, ['bb', 'aa-0', 'aa-1', 'bb']);
  });
}
