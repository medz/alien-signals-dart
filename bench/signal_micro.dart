// Microbenchmarks for signal get/set raw latency
// Run: dart run bench/signal_micro.dart

import 'package:alien_signals/alien_signals.dart';
import 'package:benchmark_harness/benchmark_harness.dart';

// ─── Raw signal read (no subscribers, clean) ─────────────────────────

class SignalReadCleanBenchmark extends BenchmarkBase {
  SignalReadCleanBenchmark() : super('signal_read_clean');

  late WritableSignal<int> s;

  @override
  void setup() {
    s = signal(42);
  }

  @override
  void run() {
    s(); // read clean signal 100 times
    s(); s(); s(); s(); s(); s(); s(); s(); s(); s();
    s(); s(); s(); s(); s(); s(); s(); s(); s(); s();
    s(); s(); s(); s(); s(); s(); s(); s(); s(); s();
    s(); s(); s(); s(); s(); s(); s(); s(); s(); s();
    s(); s(); s(); s(); s(); s(); s(); s(); s(); s();
    s(); s(); s(); s(); s(); s(); s(); s(); s(); s();
    s(); s(); s(); s(); s(); s(); s(); s(); s(); s();
    s(); s(); s(); s(); s(); s(); s(); s(); s(); s();
    s(); s(); s(); s(); s(); s(); s(); s(); s(); s();
    s(); s(); s(); s(); s(); s(); s(); s(); s(); s();
  }
}

// ─── Raw signal write (no subscribers) ───────────────────────────────

class SignalWriteNoSubsBenchmark extends BenchmarkBase {
  SignalWriteNoSubsBenchmark() : super('signal_write_no_subs');

  late WritableSignal<int> s;

  @override
  void setup() {
    s = signal(0);
  }

  @override
  void run() {
    s.set(1); s.set(2); s.set(3); s.set(4); s.set(5);
    s.set(6); s.set(7); s.set(8); s.set(9); s.set(10);
    s.set(11); s.set(12); s.set(13); s.set(14); s.set(15);
    s.set(16); s.set(17); s.set(18); s.set(19); s.set(20);
    s.set(21); s.set(22); s.set(23); s.set(24); s.set(25);
    s.set(26); s.set(27); s.set(28); s.set(29); s.set(30);
    s.set(31); s.set(32); s.set(33); s.set(34); s.set(35);
    s.set(36); s.set(37); s.set(38); s.set(39); s.set(40);
    s.set(41); s.set(42); s.set(43); s.set(44); s.set(45);
    s.set(46); s.set(47); s.set(48); s.set(49); s.set(50);
  }
}

// ─── Signal write with 1 subscriber ──────────────────────────────────

class SignalWriteOneSubBenchmark extends BenchmarkBase {
  SignalWriteOneSubBenchmark() : super('signal_write_one_sub');

  late WritableSignal<int> s;

  @override
  void setup() {
    s = signal(0);
    effect(() => s());
  }

  @override
  void run() {
    s.set(1); s.set(2); s.set(3); s.set(4); s.set(5);
    s.set(6); s.set(7); s.set(8); s.set(9); s.set(10);
  }
}

// ─── Signal write with 100 subscribers ───────────────────────────────

class SignalWriteHundredSubsBenchmark extends BenchmarkBase {
  SignalWriteHundredSubsBenchmark() : super('signal_write_100_subs');

  late WritableSignal<int> s;

  @override
  void setup() {
    s = signal(0);
    for (var i = 0; i < 100; i++) {
      effect(() => s());
    }
  }

  @override
  void run() {
    s.set(1); s.set(2); s.set(3); s.set(4); s.set(5);
  }
}

// ─── Signal write with no-change (identical value) ───────────────────

class SignalWriteNoChangeBenchmark extends BenchmarkBase {
  SignalWriteNoChangeBenchmark() : super('signal_write_no_change');

  late WritableSignal<int> s;

  @override
  void setup() {
    s = signal(42);
    effect(() => s());
  }

  @override
  void run() {
    // Set the same value — should short-circuit via identical()
    s.set(42); s.set(42); s.set(42); s.set(42); s.set(42);
    s.set(42); s.set(42); s.set(42); s.set(42); s.set(42);
    s.set(42); s.set(42); s.set(42); s.set(42); s.set(42);
    s.set(42); s.set(42); s.set(42); s.set(42); s.set(42);
    s.set(42); s.set(42); s.set(42); s.set(42); s.set(42);
    s.set(42); s.set(42); s.set(42); s.set(42); s.set(42);
    s.set(42); s.set(42); s.set(42); s.set(42); s.set(42);
    s.set(42); s.set(42); s.set(42); s.set(42); s.set(42);
    s.set(42); s.set(42); s.set(42); s.set(42); s.set(42);
    s.set(42); s.set(42); s.set(42); s.set(42); s.set(42);
  }
}

// ─── Computed read (clean, dependencies unchanged) ───────────────────

class ComputedReadCleanBenchmark extends BenchmarkBase {
  ComputedReadCleanBenchmark() : super('computed_read_clean');

  late WritableSignal<int> a;
  late WritableSignal<int> b;
  late Computed<int> sum;

  @override
  void setup() {
    a = signal(10);
    b = signal(20);
    sum = computed<int>((_) => a() + b());
    sum(); // force first computation
  }

  @override
  void run() {
    sum(); sum(); sum(); sum(); sum();
    sum(); sum(); sum(); sum(); sum();
    sum(); sum(); sum(); sum(); sum();
    sum(); sum(); sum(); sum(); sum();
    sum(); sum(); sum(); sum(); sum();
    sum(); sum(); sum(); sum(); sum();
    sum(); sum(); sum(); sum(); sum();
    sum(); sum(); sum(); sum(); sum();
    sum(); sum(); sum(); sum(); sum();
    sum(); sum(); sum(); sum(); sum();
  }
}

// ─── link() microbenchmark ───────────────────────────────────────────

class LinkCreationBenchmark extends BenchmarkBase {
  LinkCreationBenchmark() : super('link_creation');

  late WritableSignal<int> s;

  @override
  void setup() {
    s = signal(0);
  }

  @override
  void run() {
    // Create an effect that reads the signal, then immediately stop it
    // This exercises link + unlink per iteration
    final e = effect(() => s());
    e(); // stop
  }
}

// ─── Main ────────────────────────────────────────────────────────────

void main() {
  SignalReadCleanBenchmark().report();
  SignalWriteNoSubsBenchmark().report();
  SignalWriteOneSubBenchmark().report();
  SignalWriteHundredSubsBenchmark().report();
  SignalWriteNoChangeBenchmark().report();
  ComputedReadCleanBenchmark().report();
  LinkCreationBenchmark().report();
}
