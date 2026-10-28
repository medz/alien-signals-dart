import 'package:alien_signals/alien_signals.dart';

void main() {
  // #region computed
  final price = signal(10);
  final quantity = signal(2);
  var evaluations = 0; // #hide
  final total = computed((_) {
    evaluations++; // #hide
    return price() * quantity();
  });

  assert(evaluations == 0); // #hide
  print(total()); // 20; computed on the first read.
  print(total()); // 20; the cached value is reused.
  assert(evaluations == 1); // #hide

  quantity.set(3);
  assert(evaluations == 1); // #hide
  print(total()); // 30; recomputed after a dependency changes.
  assert(evaluations == 2); // #hide
  // #endregion computed
}
