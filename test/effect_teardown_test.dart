import 'package:alien_signals/alien_signals.dart';
import 'package:alien_signals/preset.dart' show EffectNode, SignalNode;
import 'package:alien_signals/system.dart' show ReactiveFlags;
import 'package:test/test.dart';

void main() {
  test(
    'stopped effect does not subscribe to signals read later in the same run',
    () {
      final rerun = signal(0);
      final readAfterStop = SignalNode(
        flags: ReactiveFlags.mutable,
        currentValue: 0,
        pendingValue: 0,
      );
      Effect? stop;
      EffectNode? node;
      bool stopDuringRun = false;
      int runs = 0;

      stop = effect(() {
        node ??= stop as EffectNode?;
        runs++;
        rerun();
        if (stopDuringRun) {
          stop!();
          readAfterStop.get();
        }
      });

      expect(runs, 1);
      expect(readAfterStop.subs, isNull);

      stopDuringRun = true;
      rerun.set(1);

      expect(runs, 2);
      expect(node!.flags, ReactiveFlags.none);
      expect(readAfterStop.subs, isNull);
    },
  );

  test('failed effect setup does not leave a live subscription behind', () {
    final source = signal(0);
    int runs = 0;

    expect(
      () => effect(() {
        runs++;
        source();
        throw StateError('setup failed');
      }),
      throwsStateError,
    );

    expect(runs, 1);
    expect(() => source.set(1), returnsNormally);
    expect(runs, 1);
  });

  test(
    'failed effect scope setup disposes child effects created before throw',
    () {
      final source = signal(0);
      int childRuns = 0;

      expect(
        () => effectScope(() {
          effect(() {
            childRuns++;
            source();
          });
          throw StateError('scope setup failed');
        }),
        throwsStateError,
      );

      expect(childRuns, 1);
      source.set(1);
      expect(childRuns, 1);
    },
  );
}
