# Performance baseline

Run the small suite in JIT mode:

```sh
dart run bench/baseline.dart
```

Run the same suite in AOT mode:

```sh
dart compile exe bench/baseline.dart -o /tmp/alien-signals-baseline
/tmp/alien-signals-baseline
```

The suite covers a 10 × 10 propagation graph, switching computed dependencies
(including a write to the inactive source), 32 writes in a batch, and creating,
updating, then disposing a signal/computed/effect graph. It checks the resulting
values and effect counts after measurement. Effects are disposed between cases;
the creation case disposes each graph inside the measured operation.

`benchmark_harness` warms up each case for at least 100 ms and measures it for
about 2 seconds. The four-case suite usually takes 10–20 seconds. Its default
`exercise()` calls `run()` **10 times**, so the reported `us` is **microseconds per
10 operations**, not per operation. Divide by 10 for the mean cost of one run.
For the batch case, one run contains 32 writes and one effect flush.

Compare the same Dart version, runtime mode, machine, and power settings. Run
each revision several times with other heavy work paused and compare medians;
small differences can be noise. Keep JIT and AOT results separate. The values
and effect counters add a small, consistent cost to keep results observable.

The creation case measures lifecycle time under repeated allocation, including
garbage collection and cleanup. It does **not** report allocated bytes or isolate
allocation time. Byte allocation needs a separate VM allocation profile; process
RSS also includes the VM and retained heap and is not a byte-allocation metric.

The existing width/depth matrix is still available separately:

```sh
dart run bench/propagate.dart
```
