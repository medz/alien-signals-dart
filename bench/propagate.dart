import 'package:alien_signals/alien_signals.dart';
import 'package:benchmark_harness/benchmark_harness.dart';

class PropagateBenchmark extends BenchmarkBase {
  PropagateBenchmark({required this.w, required this.h})
      : super('propagate: $w * $h');

  final int w;
  final int h;
  late final WritableSignal<int> src;

  @override
  void setup() {
    src = signal(1);
    for (var i = 0; i < w; i++) {
      Signal<int> last = src;
      for (var j = 0; j < h; j++) {
        final prev = last;
        last = computed<int>((_) => prev() + 1);
      }

      effect(() => last());
    }
  }

  @override
  void run() {
    src.set(src() + 1);
  }
}

void main() {
  const widths = [1, 10, 100];
  const heights = [1, 10, 100];

  for (final w in widths) {
    for (final h in heights) {
      PropagateBenchmark(w: w, h: h).report();
    }
  }
}
