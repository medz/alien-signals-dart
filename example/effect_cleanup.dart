import 'package:alien_signals/alien_signals.dart';

void main() {
  // #region cleanup
  final count = signal(0);
  final events = <String>[];
  final stop = effect(() {
    final value = count();
    events.add('run $value');
    return () => events.add('cleanup $value');
  });

  count.set(1); // Cleans up the previous run before running again.
  stop(); // Cleans up the final run.
  count.set(2); // No further runs or cleanups.
  print(events); // [run 0, cleanup 0, run 1, cleanup 1]
  const expected = 'run 0,cleanup 0,run 1,cleanup 1'; // #hide
  assert(events.join(',') == expected); // #hide
  // #endregion cleanup
}
