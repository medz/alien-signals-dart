import 'package:alien_signals/alien_signals.dart';

void main() {
  // #region scope
  final count = signal(0);
  var runs = 0; // #hide
  var cleanups = 0; // #hide
  final stop = effectScope(() {
    effect(() {
      runs++; // #hide
      print('Count: ${count()}');
      return () => cleanups++; // #hide
    });
    effectScope(() {
      effect(() {
        runs++; // #hide
        print('Doubled: ${count() * 2}');
        return () => cleanups++; // #hide
      });
    });
  });

  assert(runs == 2 && cleanups == 0); // #hide
  count.set(1); // Both effects run again.
  assert(runs == 4 && cleanups == 2); // #hide
  stop(); // Stops both effects, including the nested scope.
  assert(cleanups == 4); // #hide
  count.set(2); // Neither effect runs.
  assert(runs == 4 && cleanups == 4); // #hide
  // #endregion scope
}
