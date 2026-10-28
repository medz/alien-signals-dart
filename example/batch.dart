import 'package:alien_signals/alien_signals.dart';

void main() {
  // #region batch
  final count = signal(0);
  final values = <int>[];
  final stop = effect(() => values.add(count()));

  startBatch();
  try {
    count.set(1);
    count.set(2);
    assert(count() == 2); // #hide
    assert(values.length == 1); // #hide
  } finally {
    endBatch(); // Flushes the effect once, with the final value.
  }

  print(values); // [0, 2]
  assert(values.join(',') == '0,2'); // #hide
  stop();
  // #endregion batch
}
