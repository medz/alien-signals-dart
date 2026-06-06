// Topology-specific benchmarks for alien-signals-dart performance analysis.
// Run: dart run bench/topology_bench.dart

import 'package:alien_signals/alien_signals.dart';
import 'package:benchmark_harness/benchmark_harness.dart';

// ─── Topology 1: Deep Chain ───────────────────────────────────────────
// signal → computed₁ → computed₂ → ... → computedₙ → effect
// Measures: lazy pull cascade latency, shallowPropagate chain efficiency

class DeepChainBenchmark extends BenchmarkBase {
  DeepChainBenchmark(this.depth) : super('deep_chain: depth=$depth');

  final int depth;
  late WritableSignal<int> src;

  @override
  void setup() {
    src = signal(0);
    Signal<int> last = src;
    for (var i = 0; i < depth; i++) {
      final prev = last;
      last = computed<int>((_) => prev() + 1);
    }
    effect(() => last());
  }

  @override
  void run() {
    src.set(src() + 1);
  }
}

// ─── Topology 2: Wide Fan-Out ────────────────────────────────────────
// signal → effect₁, effect₂, ..., effectₙ
// Measures: subscriber list traversal in propagate/shallowPropagate

class WideFanOutBenchmark extends BenchmarkBase {
  WideFanOutBenchmark(this.count) : super('wide_fan_out: effects=$count');

  final int count;
  late WritableSignal<int> src;

  @override
  void setup() {
    src = signal(0);
    for (var i = 0; i < count; i++) {
      effect(() => src());
    }
  }

  @override
  void run() {
    src.set(src() + 1);
  }
}

// ─── Topology 3: Diamond Dependency ──────────────────────────────────
//             ┌─ computed₁ ─┐
// signal ─────┼─ computed₂ ─┼──── final_computed ──── effect
//             └─ computedₙ ─┘
// Measures: deduplication of intermediate signals feeding one output

class DiamondBenchmark extends BenchmarkBase {
  DiamondBenchmark(this.width) : super('diamond: width=$width');

  final int width;
  late WritableSignal<int> src;

  @override
  void setup() {
    src = signal(0);
    final intermediates = <Computed<int>>[];
    for (var i = 0; i < width; i++) {
      intermediates.add(computed<int>((_) => src() + i));
    }
    final last = computed<int>((_) {
      var sum = 0;
      for (final c in intermediates) {
        sum += c();
      }
      return sum;
    });
    effect(() => last());
  }

  @override
  void run() {
    src.set(src() + 1);
  }
}

// ─── Topology 4: Wide Fan-In ─────────────────────────────────────────
// signal₁, signal₂, ..., signalₙ → computed → effect
// Measures: dependency tracking cost during computation (link creation)

class WideFanInBenchmark extends BenchmarkBase {
  WideFanInBenchmark(this.count) : super('wide_fan_in: signals=$count');

  final int count;
  late List<WritableSignal<int>> signals;
  late WritableSignal<int> trigger;

  @override
  void setup() {
    signals = List.generate(count, (i) => signal(i));
    final c = computed<int>((_) {
      var sum = 0;
      for (final s in signals) {
        sum += s();
      }
      return sum;
    });
    effect(() => c());
    trigger = signal(0); // unrelated signal to measure pure propagation
  }

  @override
  void run() {
    // Update first signal only — all deps already linked
    signals[0].set(signals[0]() + 1);
  }
}

// ─── Topology 5: Batched Writes ──────────────────────────────────────
// N signals updated inside startBatch/endBatch
// Measures: batch coalescing efficiency, flush throughput

class BatchedWritesBenchmark extends BenchmarkBase {
  BatchedWritesBenchmark(this.count, this.useBatch)
    : super('batched_writes: signals=$count batch=$useBatch');

  final int count;
  final bool useBatch;
  late List<WritableSignal<int>> signals;

  @override
  void setup() {
    signals = List.generate(count, (_) => signal(0));
    for (final s in signals) {
      effect(() => s());
    }
  }

  @override
  void run() {
    if (useBatch) startBatch();
    for (var i = 0; i < count; i++) {
      signals[i].set(i);
    }
    if (useBatch) endBatch();
  }
}

// ─── Topology 6: Create/Destroy Churn ────────────────────────────────
// Repeatedly create and destroy effects
// Measures: lifecycle overhead (link/unlink, cleanup, GC pressure)

class ChurnBenchmark extends BenchmarkBase {
  ChurnBenchmark(this.groupSize)
    : super('churn: group_size=$groupSize');

  final int groupSize;
  late WritableSignal<int> src;

  @override
  void setup() {
    src = signal(0);
  }

  @override
  void run() {
    final effects = <Effect>[];
    for (var i = 0; i < groupSize; i++) {
      effects.add(effect(() => src()));
    }
    for (final e in effects) {
      e(); // stop each effect
    }
  }
}

// ─── Topology 7: Rapid Toggle ────────────────────────────────────────
// Signal oscillates between two values
// Measures: short-circuit when pendingValue != newValue is true/false

class RapidToggleBenchmark extends BenchmarkBase {
  RapidToggleBenchmark(this.computesPerChain)
    : super('rapid_toggle: chain=$computesPerChain');

  final int computesPerChain;
  late WritableSignal<int> src;

  @override
  void setup() {
    src = signal(0);
  }

  @override
  void run() {
    // Repeatedly set toggling values
    for (var i = 0; i < 100; i++) {
      src.set(i % 2); // toggles 0→1→0→1
    }
  }
}

// ─── Topology 8: Computed Chain (Read-Only) ─────────────────────────
// Deep computed chain, measure get() latency after update
// Measures: lazy pull cascade cost

class ComputedChainReadBenchmark extends BenchmarkBase {
  ComputedChainReadBenchmark(this.depth)
    : super('computed_read: depth=$depth');

  final int depth;
  late WritableSignal<int> src;
  late Signal<int> last;

  @override
  void setup() {
    src = signal(0);
    Signal<int> cur = src;
    for (var i = 0; i < depth; i++) {
      final prev = cur;
      cur = computed<int>((_) => prev() + 1);
    }
    last = cur;
  }

  @override
  void run() {
    src.set(src() + 1);
    last(); // trigger full lazy pull cascade
  }
}

// ─── Main ────────────────────────────────────────────────────────────

void main() {
  // Deep chain
  for (final d in [10, 100, 500, 1000]) {
    DeepChainBenchmark(d).report();
  }

  // Wide fan-out
  for (final w in [10, 100, 500, 1000]) {
    WideFanOutBenchmark(w).report();
  }

  // Diamond
  for (final w in [5, 10, 50, 100]) {
    DiamondBenchmark(w).report();
  }

  // Wide fan-in
  for (final c in [10, 100, 500]) {
    WideFanInBenchmark(c).report();
  }

  // Batched writes
  for (final batch in [false, true]) {
    for (final c in [10, 100, 500]) {
      BatchedWritesBenchmark(c, batch).report();
    }
  }

  // Churn
  for (final g in [10, 100, 500]) {
    ChurnBenchmark(g).report();
  }

  // Rapid toggle
  for (final c in [1, 10]) {
    RapidToggleBenchmark(c).report();
  }

  // Computed read chain
  for (final d in [10, 100, 500]) {
    ComputedChainReadBenchmark(d).report();
  }
}
