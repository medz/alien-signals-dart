import 'package:alien_signals/alien_signals.dart';
import 'package:alien_signals/preset.dart' show checkDirty;
import 'package:alien_signals/system.dart' show ReactiveNode;
import 'package:test/test.dart';

(Object, StackTrace) capture(void Function() fn) {
  try {
    fn();
  } catch (e, s) {
    return (e, s);
  }
  throw StateError('expected error');
}

void main() {
  test('root dirty check retries only an invalidated cached failure', () {
    final source = signal(0);
    var calls = 0;
    final value = computed<int>((_) {
      source();
      if (++calls == 1) throw StateError('x');
      return 7;
    });
    expect(() => value(), throwsStateError);
    final node = value as ReactiveNode;
    expect(checkDirty(node.deps!, node), false);
    expect(calls, 1);
    source.set(1);
    source.set(0);
    expect(checkDirty(node.deps!, node), true);
    expect(value(), 7);
    expect(calls, 2);
  });

  for (final catches in [false, true]) {
    test('nested restoring-write, outer catches=$catches', () {
      final source = signal('a');
      var failNext = true, innerCalls = 0, outerCalls = 0;
      final inner = computed<String>((_) {
        innerCalls++;
        final key = source();
        if (failNext) {
          failNext = false;
          throw StateError('open $key failed');
        }
        return 'opened $key';
      });
      final outer = computed<String>((_) {
        outerCalls++;
        if (catches) {
          try {
            return inner();
          } catch (_) {
            return 'fallback';
          }
        }
        return inner();
      });
      if (catches) {
        expect(outer(), 'fallback');
      } else {
        expect(() => outer(), throwsStateError);
      }
      source.set('b');
      source.set('a');
      expect(outer(), 'opened a');
      expect(inner(), 'opened a');
      expect(innerCalls, 2);
      expect(outerCalls, 2);
    });
  }
  test('explicit outer dirty checking settles inner before direct read', () {
    final source = signal('a');
    var calls = 0;
    final inner = computed<String>((_) {
      final v = source();
      if (++calls == 1) throw StateError('failed');
      return v;
    });
    final outer = computed((_) => inner());
    expect(() => outer(), throwsStateError);
    source.set('b');
    source.set('a');
    final n = outer as ReactiveNode;
    expect(checkDirty(n.deps!, n), true);
    expect(inner(), 'a');
    expect(calls, 2);
    expect(outer(), 'a');
    expect(calls, 2);
  });
  for (final nesting in [false, true]) {
    test('batched restore wakes effect, nesting=$nesting', () {
      final source = signal('a');
      var calls = 0;
      final inner = computed<String>((_) {
        final v = source();
        if (++calls == 1) throw StateError('failed');
        return v;
      });
      final value = nesting ? computed((_) => inner()) : inner;
      final seen = <String>[];
      final stop = effect(() {
        try {
          seen.add(value());
        } catch (_) {
          seen.add('error');
        }
      });
      startBatch();
      source.set('b');
      source.set('a');
      endBatch();
      expect(seen, ['error', 'a']);
      expect(calls, 2);
      stop();
    });
  }
  test(
    'unchanged successful intermediate does not prevent failed descendant retry',
    () {
      final source = signal(0);
      var stableCalls = 0, failedCalls = 0;
      final stable = computed((_) {
        stableCalls++;
        source();
        return 1;
      });
      final inner = computed((_) {
        final v = stable();
        if (++failedCalls == 1) throw StateError('x');
        return v;
      });
      final outer = computed((_) => inner());
      expect(() => outer(), throwsStateError);
      source.set(1);
      source.set(0);
      expect(outer(), 1);
      expect(stableCalls, 1);
      expect(failedCalls, 2);
    },
  );
  test('successful chain retains cache after restore', () {
    final source = signal(0);
    var calls = 0;
    final inner = computed((_) {
      calls++;
      return source();
    });
    final outer = computed((_) {
      calls++;
      return inner();
    });
    expect(outer(), 0);
    source.set(1);
    source.set(0);
    expect(outer(), 0);
    expect(calls, 2);
  });
  test('same-value write does not invalidate errors', () {
    final source = signal('a');
    var calls = 0;
    final inner = computed<String>((_) {
      calls++;
      source();
      throw StateError('x');
    });
    final outer = computed((_) => inner());
    final first = capture(() => outer());
    source.set('a');
    final next = capture(() => outer());
    expect(next.$1, same(first.$1));
    expect(next.$2.toString(), first.$2.toString());
    expect(calls, 1);
  });
  test('failed retry replaces error and then caches its stack', () {
    final source = signal(0);
    var calls = 0;
    final inner = computed<int>((_) {
      source();
      calls++;
      throw StateError('attempt $calls');
    });
    final outer = computed((_) => inner());
    final first = capture(() => outer());
    source.set(1);
    source.set(0);
    final second = capture(() => outer());
    final third = capture(() => outer());
    expect(second.$1, isNot(same(first.$1)));
    expect(third.$1, same(second.$1));
    expect(third.$2.toString(), second.$2.toString());
    expect(calls, 2);
    source.set(1);
    source.set(0);
    capture(() => outer());
    expect(calls, 3);
  });
  test(
    'diamond shared failed dependency retries once and notifies all effects',
    () {
      final source = signal(0);
      var calls = 0;
      final inner = computed<int>((_) {
        source();
        if (++calls == 1) throw StateError('x');
        return 7;
      });
      final left = computed((_) => inner() + 1);
      final right = computed((_) => inner() + 2);
      final combined = computed((_) => left() + right());
      final seenLeft = <int>[], seenRight = <int>[], seenCombined = <int>[];
      void record(List<int> values, Computed<int> c) {
        try {
          values.add(c());
        } catch (_) {
          values.add(-1);
        }
      }

      final stops = [
        effect(() => record(seenLeft, left)),
        effect(() => record(seenRight, right)),
        effect(() => record(seenCombined, combined)),
      ];
      startBatch();
      source.set(1);
      source.set(0);
      endBatch();
      expect(calls, 2);
      expect(seenLeft, [-1, 8]);
      expect(seenRight, [-1, 9]);
      expect(seenCombined, [-1, 17]);
      for (final stop in stops) {
        stop();
      }
    },
  );
  test(
    'retry keeps previous successful nullable result and notifies same-value recovery',
    () {
      final source = signal(0);
      var shouldFail = false;
      final previous = <int?>[];
      final inner = computed<int?>((prev) {
        previous.add(prev);
        source();
        if (shouldFail) throw StateError('x');
        return null;
      });
      final outer = computed<int?>((_) => inner());
      final seen = <Object?>[];
      final stop = effect(() {
        try {
          seen.add(outer());
        } catch (_) {
          seen.add('error');
        }
      });
      shouldFail = true;
      source.set(1);
      shouldFail = false;
      startBatch();
      source.set(2);
      source.set(1);
      endBatch();
      expect(seen, [null, 'error', null]);
      expect(previous, [null, null, null]);
      stop();
    },
  );
  test('retry keeps last successful non-null previous value', () {
    final source = signal(0);
    var shouldFail = false;
    final previous = <int?>[];
    final inner = computed<int>((prev) {
      previous.add(prev);
      source();
      if (shouldFail) throw StateError('x');
      return 42;
    });
    final outer = computed((_) => inner());
    expect(outer(), 42);
    shouldFail = true;
    source.set(1);
    expect(() => outer(), throwsStateError);
    shouldFail = false;
    source.set(2);
    source.set(1);
    expect(outer(), 42);
    expect(previous, [null, 42, 42]);
  });
  test('retry switches and purges dependencies after failure', () {
    final source = signal(0), left = signal(1), right = signal(10);
    var useLeft = true, calls = 0;
    final inner = computed<int>((_) {
      source();
      calls++;
      final v = useLeft ? left() : right();
      if (calls == 1) throw StateError('x');
      return v;
    });
    final outer = computed((_) => inner());
    expect(() => outer(), throwsStateError);
    useLeft = false;
    source.set(1);
    source.set(0);
    expect(outer(), 10);
    left.set(2);
    expect(outer(), 10);
    expect(calls, 2);
    right.set(11);
    expect(outer(), 11);
    expect(calls, 3);
  });
  test('successful recovery clears retry metadata', () {
    final source = signal(0);
    var calls = 0;
    final inner = computed<int>((_) {
      source();
      if (++calls == 1) throw StateError('x');
      return 7;
    });
    final outer = computed((_) => inner());
    expect(() => outer(), throwsStateError);
    source.set(1);
    source.set(0);
    expect(outer(), 7);
    expect(calls, 2);
    source.set(1);
    source.set(0);
    expect(outer(), 7);
    expect(calls, 2);
  });
  test('unchanged fallback output suppresses effects after recovery', () {
    final source = signal(0);
    var innerCalls = 0, outerCalls = 0, effectCalls = 0;
    final inner = computed<int>((_) {
      source();
      if (++innerCalls == 1) throw StateError('x');
      return 7;
    });
    final outer = computed<int>((_) {
      outerCalls++;
      try {
        inner();
      } catch (_) {}
      return 0;
    });
    final stop = effect(() {
      outer();
      effectCalls++;
    });
    startBatch();
    source.set(1);
    source.set(0);
    endBatch();
    expect(innerCalls, 2);
    expect(outerCalls, 2);
    expect(effectCalls, 1);
    stop();
  });
  test('same error object retries only once per invalidation', () {
    final source = signal(0);
    final error = StateError('x');
    var calls = 0;
    final inner = computed<int>((_) {
      source();
      calls++;
      throw error;
    });
    final outer = computed((_) => inner());
    final seen = <Object>[];
    final stop = effect(() {
      try {
        outer();
      } catch (e) {
        seen.add(e);
      }
    });
    startBatch();
    source.set(1);
    source.set(0);
    endBatch();
    final first = capture(() => outer()), second = capture(() => outer());
    expect(calls, 2);
    expect(seen, [same(error), same(error)]);
    expect(first.$2.toString(), second.$2.toString());
    stop();
  });
  test('retry disposes and recreates child effects', () {
    final source = signal(0), childSource = signal(0);
    var calls = 0, childRuns = 0, cleanups = 0;
    final inner = computed<int>((_) {
      source();
      effect(() {
        childSource();
        childRuns++;
        return () {
          cleanups++;
        };
      });
      if (++calls == 1) throw StateError('x');
      return 1;
    });
    final outer = computed((_) => inner());
    expect(() => outer(), throwsStateError);
    source.set(1);
    source.set(0);
    expect(outer(), 1);
    expect(calls, 2);
    expect(childRuns, 2);
    expect(cleanups, 1);
    childSource.set(1);
    expect(childRuns, 3);
    expect(cleanups, 2);
  });
  test(
    '20,000 already-evaluated failed computed levels settle iteratively',
    () {
      final source = signal(0);
      var calls = 0;
      Computed<int> value = computed((_) {
        source();
        if (++calls == 1) throw StateError('x');
        return 1;
      });
      expect(() => value(), throwsStateError);
      for (var i = 0; i < 20000; i++) {
        final dep = value;
        value = computed((_) => dep() + 1);
        expect(() => value(), throwsStateError);
      }
      source.set(1);
      source.set(0);
      expect(value(), 20001);
      expect(calls, 2);
    },
  );
}
