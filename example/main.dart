import 'package:alien_signals/alien_signals.dart';

void main() {
  // #region basic
  final count = signal(0);
  final doubled = computed((_) => count() * 2);
  var runs = 0; // #hide

  final stop = effect(() {
    runs++; // #hide
    print('Count: ${count()}, Doubled: ${doubled()}');
  }); // Count: 0, Doubled: 0

  count.set(1); // Count: 1, Doubled: 2
  assert(runs == 2 && doubled() == 2); // #hide
  stop();
  count.set(2); // The stopped effect no longer runs.
  assert(runs == 2 && doubled() == 4); // #hide
  // #endregion basic
}
