import 'package:alien_signals/alien_signals.dart' as alien_signals;
import 'package:reactivity_benchmark/reactive_framework.dart';
import 'package:reactivity_benchmark/run_framework_bench.dart';
import 'package:reactivity_benchmark/utils/create_computed.dart';
import 'package:reactivity_benchmark/utils/create_signal.dart';

class Bench extends ReactiveFramework {
  const Bench() : super("alien_signals");

  @override
  Computed<T> computed<T>(T Function() fn) {
    return createComputed(alien_signals.computed<T>((_) => fn()));
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

void main() {
  print('Running alien-signals performance benchmark...');
  final stopwatch = Stopwatch()..start();
  
  runFrameworkBench(const Bench());
  
  stopwatch.stop();
  print('Benchmark completed in ${stopwatch.elapsedMilliseconds}ms');
}
