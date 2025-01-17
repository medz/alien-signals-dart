import 'package:alien_signals/preset.dart' as alien_signals;
import 'package:reactivity_benchmark/reactive_framework.dart';
import 'package:reactivity_benchmark/run_framework_bench.dart';
import 'package:reactivity_benchmark/utils/create_computed.dart';
import 'package:reactivity_benchmark/utils/create_signal.dart';

final class _AlienSignalReactiveFramework extends ReactiveFramework {
  const _AlienSignalReactiveFramework() : super('alien-signals');

  @override
  Computed<T> computed<T>(T Function() fn) {
    final computed = alien_signals.computed<T>((_) => fn());
    return createComputed(computed);
  }

  @override
  void effect(void Function() fn) {
    alien_signals.effect(fn);
  }

  @override
  Signal<T> signal<T>(T value) {
    final signal = alien_signals.signal(value);
    return createSignal(signal, signal);
  }

  @override
  void withBatch<T>(T Function() fn) {
    alien_signals.startBatch();
    fn();
    alien_signals.endBatch();
  }

  @override
  T withBuild<T>(T Function() fn) {
    return fn();
  }
}

main() {
  final framework = const _AlienSignalReactiveFramework();
  runFrameworkBench(framework);
}
