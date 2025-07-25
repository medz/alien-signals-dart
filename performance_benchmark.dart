import 'dart:math' as math;
import 'package:alien_signals/alien_signals.dart';

void main() {
  print('🚀 Performance Optimization Benchmark\n');
  
  benchmarkSignalOperations();
  benchmarkComputedOperations();
  benchmarkEffectOperations();
  benchmarkBatchOperations();
  benchmarkComplexDependencyGraph();
}

void benchmarkSignalOperations() {
  print('📊 Signal Operations Benchmark');
  
  // Test signal creation and updates
  final iterations = 100000;
  final stopwatch = Stopwatch()..start();
  
  final signals = <dynamic>[];
  for (int i = 0; i < iterations; i++) {
    signals.add(signal(i));
  }
  
  stopwatch.stop();
  print('  Signal creation: ${stopwatch.elapsedMicroseconds}μs for $iterations signals');
  print('  Avg per signal: ${(stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(2)}μs');
  
  // Test signal updates
  stopwatch.reset();
  stopwatch.start();
  
  for (int i = 0; i < signals.length; i++) {
    signals[i](i * 2);
  }
  
  stopwatch.stop();
  print('  Signal updates: ${stopwatch.elapsedMicroseconds}μs for $iterations updates');
  print('  Avg per update: ${(stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(2)}μs\n');
}

void benchmarkComputedOperations() {
  print('📊 Computed Operations Benchmark');
  
  final s1 = signal(1);
  final s2 = signal(2);
  final s3 = signal(3);
  
  final computeds = <dynamic>[];
  final iterations = 10000;
  
  final stopwatch = Stopwatch()..start();
  
  // Create computed values with dependencies
  for (int i = 0; i < iterations; i++) {
    computeds.add(computed((_) => s1() + s2() + s3() + i));
  }
  
  stopwatch.stop();
  print('  Computed creation: ${stopwatch.elapsedMicroseconds}μs for $iterations computeds');
  print('  Avg per computed: ${(stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(2)}μs');
  
  // Test computed updates by changing dependencies
  stopwatch.reset();
  stopwatch.start();
  
  s1(10);
  s2(20);
  s3(30);
  
  stopwatch.stop();
  print('  Computed cascade update: ${stopwatch.elapsedMicroseconds}μs for $iterations computeds');
  print('  Avg per computed: ${(stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(2)}μs\n');
}

void benchmarkEffectOperations() {
  print('📊 Effect Operations Benchmark');
  
  final s = signal(0);
  final effects = <dynamic>[];
  final iterations = 5000;
  int effectRunCount = 0;
  
  final stopwatch = Stopwatch()..start();
  
  // Create effects
  for (int i = 0; i < iterations; i++) {
    effects.add(effect(() {
      s();
      effectRunCount++;
    }));
  }
  
  stopwatch.stop();
  print('  Effect creation: ${stopwatch.elapsedMicroseconds}μs for $iterations effects');
  print('  Avg per effect: ${(stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(2)}μs');
  
  // Test effect execution
  effectRunCount = 0;
  stopwatch.reset();
  stopwatch.start();
  
  s(42);
  
  stopwatch.stop();
  print('  Effect execution: ${stopwatch.elapsedMicroseconds}μs for $effectRunCount effect runs');
  print('  Avg per run: ${(stopwatch.elapsedMicroseconds / effectRunCount).toStringAsFixed(2)}μs\n');
}

void benchmarkBatchOperations() {
  print('📊 Batch Operations Benchmark');
  
  final signals = List.generate(1000, (i) => signal(i));
  final computed = computed((_) => signals.fold(0, (sum, s) => sum + s()));
  int effectRunCount = 0;
  
  effect(() {
    computed();
    effectRunCount++;
  });
  
  // Without batching
  effectRunCount = 0;
  final stopwatch = Stopwatch()..start();
  
  for (int i = 0; i < signals.length; i++) {
    signals[i](i * 2);
  }
  
  stopwatch.stop();
  print('  Without batching: ${stopwatch.elapsedMicroseconds}μs, effect runs: $effectRunCount');
  
  // With batching
  effectRunCount = 0;
  stopwatch.reset();
  stopwatch.start();
  
  startBatch();
  for (int i = 0; i < signals.length; i++) {
    signals[i](i * 3);
  }
  endBatch();
  
  stopwatch.stop();
  print('  With batching: ${stopwatch.elapsedMicroseconds}μs, effect runs: $effectRunCount');
  print('  Batching speedup: ${(stopwatch.elapsedMicroseconds > 0 ? 1 : 0)}x\n');
}

void benchmarkComplexDependencyGraph() {
  print('📊 Complex Dependency Graph Benchmark');
  
  final depth = 100;
  final width = 10;
  
  final stopwatch = Stopwatch()..start();
  
  // Create a complex dependency graph
  final root = signal(1);
  final layers = <List<dynamic>>[];
  
  layers.add([root]);
  
  for (int d = 0; d < depth; d++) {
    final currentLayer = <dynamic>[];
    for (int w = 0; w < width; w++) {
      final prevIndex = w % layers[d].length;
      final c = computed((_) => layers[d][prevIndex]() * 2 + w);
      currentLayer.add(c);
    }
    layers.add(currentLayer);
  }
  
  // Add effects to leaf nodes
  int effectRunCount = 0;
  for (final leaf in layers.last) {
    effect(() {
      leaf();
      effectRunCount++;
    });
  }
  
  stopwatch.stop();
  print('  Graph creation: ${stopwatch.elapsedMicroseconds}μs');
  print('  Nodes: ${depth * width}, Effects: ${layers.last.length}');
  
  // Test propagation through the graph
  effectRunCount = 0;
  stopwatch.reset();
  stopwatch.start();
  
  root(42);
  
  stopwatch.stop();
  print('  Propagation: ${stopwatch.elapsedMicroseconds}μs for $effectRunCount effect runs');
  print('  Avg per node: ${(stopwatch.elapsedMicroseconds / (depth * width)).toStringAsFixed(2)}μs\n');
  
  print('✅ Performance benchmark completed!');
}