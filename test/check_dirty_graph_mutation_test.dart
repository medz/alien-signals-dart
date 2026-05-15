import 'package:alien_signals/alien_signals.dart';
import 'package:alien_signals/preset.dart' show getActiveSub;
import 'package:alien_signals/system.dart' show ReactiveFlags, ReactiveNode;
import 'package:test/test.dart';

void main() {
  test('disposing an effect during computed dirty checking is safe', () {
    final shouldDispose = signal(false);
    late Effect stop;

    final inner = computed((_) {
      if (shouldDispose()) stop();
      return 0;
    });
    final outer = computed((_) => inner());

    stop = effect(() {
      outer();
    });

    shouldDispose.set(true);
  });

  test('effect disposed during another update stays detached', () {
    final source = signal(0);
    late Effect stopFirst;
    ReactiveNode? firstNode;
    int firstRuns = 0;
    int secondValue = -1;
    int thirdValue = -1;

    final derived = computed((_) {
      final value = source();
      if (value == 1) stopFirst();
      return value;
    });

    stopFirst = effect(() {
      firstNode ??= getActiveSub();
      derived();
      firstRuns++;
    });
    effect(() {
      secondValue = derived();
    });
    effect(() {
      thirdValue = derived();
    });

    expect(firstRuns, 1);
    expect(secondValue, 0);
    expect(thirdValue, 0);

    source.set(1);
    expect(firstRuns, 1);
    expect(secondValue, 1);
    expect(thirdValue, 1);
    expect(firstNode!.deps, isNull);
    expect(firstNode!.flags & ReactiveFlags.watching, ReactiveFlags.none);

    source.set(2);
    expect(firstRuns, 1);
    expect(secondValue, 2);
    expect(thirdValue, 2);
  });

  test('disposing an effect scope during computed update is safe', () {
    final shouldDispose = signal(false);
    late EffectScope stopScope;

    final inner = computed((_) {
      if (shouldDispose()) stopScope();
      return 0;
    });
    final outer = computed((_) => inner());

    stopScope = effectScope(() {
      effect(() {
        outer();
      });
    });

    shouldDispose.set(true);
  });

  test('dirty checking handles a dependency that loses subscribers', () {
    final source = signal(0);
    late Effect stop;

    final stable = computed((_) {
      source();
      return 0;
    });
    final disposing = computed((_) {
      final value = source();
      if (value != 0) stop();
      return value;
    });
    final combined = computed((_) {
      stable();
      disposing();
      return 0;
    });

    stop = effect(() {
      combined();
    });

    source.set(1);
  });
}
