import 'package:alien_signals/alien_signals.dart';
import 'package:benchmark_harness/benchmark_harness.dart';

import 'propagate.dart' show PropagateBenchmark;

class DynamicDependenciesBenchmark extends BenchmarkBase {
  DynamicDependenciesBenchmark() : super('switch dependency + update');

  late final WritableSignal<bool> useLeft;
  late final WritableSignal<int> left;
  late final WritableSignal<int> right;
  late final EffectScope scope;
  var observed = 0;
  var effectRuns = 0;

  @override
  void setup() {
    useLeft = signal(true);
    left = signal(0);
    right = signal(1);
    final selected = computed((_) => useLeft() ? left() : right());
    scope = effectScope(() {
      effect(() {
        observed = selected();
        ++effectRuns;
      });
    });
  }

  @override
  void run() {
    useLeft.set(!useLeft());
    final active = useLeft() ? left : right;
    final inactive = useLeft() ? right : left;
    inactive.set(inactive() + 2);
    active.set(active() + 2);
  }

  @override
  void teardown() {
    scope();
    final expected = useLeft() ? left() : right();
    if (observed != expected || effectRuns != left() + 1) {
      throw StateError(
        'Dependency switching result or effect count is incorrect.',
      );
    }
  }
}

class BatchWritesBenchmark extends BenchmarkBase {
  BatchWritesBenchmark() : super('batch: 32 writes');

  static const writes = 32;
  late final WritableSignal<int> src;
  late final EffectScope scope;
  var observed = 0;
  var effectRuns = 0;

  @override
  void setup() {
    src = signal(0);
    final doubled = computed((_) => src() * 2);
    scope = effectScope(() {
      effect(() {
        observed = doubled();
        ++effectRuns;
      });
    });
  }

  @override
  void run() {
    final initial = src();
    startBatch();
    try {
      for (var i = 1; i <= writes; i++) {
        src.set(initial + i);
      }
    } finally {
      endBatch();
    }
  }

  @override
  void teardown() {
    scope();
    if (observed != src() * 2 || effectRuns != src() ~/ writes + 1) {
      throw StateError('Batch result or effect count is incorrect.');
    }
  }
}

class CreateGraphBenchmark extends BenchmarkBase {
  CreateGraphBenchmark() : super('create + update + dispose graph');

  var graphs = 0;
  var observed = 0;
  var effectRuns = 0;

  @override
  void run() {
    final src = signal(graphs);
    final doubled = computed((_) => src() * 2);
    final scope = effectScope(() {
      effect(() {
        observed += doubled();
        ++effectRuns;
      });
    });
    try {
      src.set(graphs + 1);
    } finally {
      scope();
    }
    src.set(graphs + 2);
    ++graphs;
  }

  @override
  void teardown() {
    if (observed != 2 * graphs * graphs || effectRuns != 2 * graphs) {
      throw StateError('Graph lifecycle result or effect count is incorrect.');
    }
  }
}

void main() {
  PropagateBenchmark(w: 10, h: 10).report();
  DynamicDependenciesBenchmark().report();
  BatchWritesBenchmark().report();
  CreateGraphBenchmark().report();
}
