// Memory allocation profiling for alien-signals-dart
// Run: dart run --observe bench/memory_profile.dart
// Then open Observatory URL to inspect heap

import 'dart:isolate';
import 'package:alien_signals/alien_signals.dart';

void main() async {
  // Warm up
  print('Warming up...');
  for (var i = 0; i < 1000; i++) {
    final s = signal(i);
    final c = computed<int>((_) => s() * 2);
    final e = effect(() => c());
    e();
  }

  // Trigger GC
  print('Triggering GC...');
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  // Build a large graph and measure
  print('Building large graph (100x100 grid)...');
  final before = DateTime.now();
  final src = signal(1);
  for (var i = 0; i < 100; i++) {
    Signal<int> last = src;
    for (var j = 0; j < 100; j++) {
      final prev = last;
      last = computed<int>((_) => prev() + 1);
    }
    effect(() => last());
  }
  final buildTime = DateTime.now().difference(before);
  print('Build time: ${buildTime.inMilliseconds}ms');

  // Measure propagation time
  print('Measuring 1000 propagations...');
  final start = DateTime.now();
  for (var i = 0; i < 1000; i++) {
    src.set(src() + 1);
  }
  final propagateTime = DateTime.now().difference(start);
  print('1000 propagations: ${propagateTime.inMilliseconds}ms');
  print('Per propagation: ${propagateTime.inMicroseconds / 1000} µs');

  // Memory stats
  print('\n--- Memory Estimates ---');
  print('Signals: 1');
  print('Computeds: ${100 * 100} = 10,000');
  print('Effects: 100');
  print('Links: ~10,100 (one per edge in the dependency graph)');
  print('Each Link: ~56 bytes (8 fields × 8 bytes - but heap objects have overhead)');
  print('Each SignalNode: ~72 bytes');
  print('Each ComputedNode: ~72 bytes');
  print('Each EffectNode: ~80 bytes');
  print('Total estimated heap: ~${(1 * 72 + 10000 * 72 + 100 * 80 + 10100 * 56) ~/ 1024} KB');

  print('\nDone. Send SIGQUIT (kill -3) to this process for a full heap dump.');
  print('Or connect Observatory to inspect allocations in real time.');
  print('PID: ${Isolate.current.hashCode}');

  // Keep alive
  await Future<void>.delayed(const Duration(seconds: 5));
}
