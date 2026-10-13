import 'package:alien_signals/alien_signals.dart';
import 'package:alien_signals/system.dart';
import 'package:alien_signals/preset.dart' show checkDirty;
import 'package:test/test.dart';

void main() {
  test('repeated root dirty checks do not consume the retry token', () {
    final source = signal(0);
    var calls = 0;
    final value = computed<int>((_) {
      source();
      if (++calls == 1) throw StateError('x');
      return 42;
    });
    expect(() => value(), throwsStateError);
    final node = value as ReactiveNode;
    expect(checkDirty(node.deps!, node), false);
    expect(checkDirty(node.deps!, node), false);
    source.set(1);
    source.set(0);
    expect(checkDirty(node.deps!, node), true);
    expect(checkDirty(node.deps!, node), true);
    expect(calls, 1);
    expect(value(), 42);
    expect(calls, 2);
  });
  test('failed child-effect retries rearm the removed retry dependency', () {
    final source = signal(0);
    var calls = 0, cleanups = 0;
    final value = computed<int>((_) {
      source();
      effect(
        () => () {
          cleanups++;
        },
      );
      calls++;
      throw StateError('x');
    });
    final outer = computed((_) => value());
    expect(() => outer(), throwsStateError);
    for (var i = 0; i < 3; i++) {
      source.set(1);
      source.set(0);
      expect(() => outer(), throwsStateError);
    }
    expect(calls, 4);
    expect(cleanups, 3);
  });

  test('dependency-free failure stays cached after subscriber disposal', () {
    var calls = 0;
    final value = computed<int>((_) {
      calls++;
      throw StateError('x');
    });
    final stop = effect(() {
      try {
        value();
      } catch (_) {}
    });
    stop();
    expect(() => value(), throwsStateError);
    expect(calls, 1);
    expect((value as ReactiveNode).deps, isNull);
  });
  test('failed retry can drop all real dependencies and stay cached', () {
    var calls = 0;
    final source = signal(0);
    final value = computed<int>((_) {
      if (++calls == 1) source();
      throw StateError('x');
    });
    final stop = effect(() {
      try {
        value();
      } catch (_) {}
    });
    source.set(1);
    expect(calls, 2);
    stop();
    expect(() => value(), throwsStateError);
    expect(calls, 2);
    expect((value as ReactiveNode).deps, isNull);
  });
  test('successful recovery removes the synthetic dependency', () {
    final source = signal(0);
    var calls = 0;
    final value = computed<int>((_) {
      source();
      if (++calls == 1) throw StateError('x');
      return 42;
    });
    expect(() => value(), throwsStateError);
    expect((value as ReactiveNode).deps!.nextDep, isNotNull);
    source.set(1);
    source.set(0);
    expect(value(), 42);
    expect((value as ReactiveNode).deps!.nextDep, isNull);
  });
}
