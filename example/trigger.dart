import 'package:alien_signals/alien_signals.dart';

void main() {
  // #region trigger
  final items = signal(<String>[]);
  final lengths = <int>[];
  final stop = effect(() => lengths.add(items().length));

  items().add('new item');
  items.set(items()); // The same object does not notify readers.
  print(lengths); // [0]
  assert(lengths.join(',') == '0'); // #hide

  trigger(() => items()); // Explicitly notifies readers of this signal.
  print(lengths); // [0, 1]
  assert(lengths.join(',') == '0,1'); // #hide
  stop();
  // #endregion trigger
}
