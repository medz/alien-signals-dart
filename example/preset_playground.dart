import 'package:alien_signals/alien_signals.dart' show effect;
import 'package:alien_signals/preset.dart';

// #region wrappers
extension type Signal<T>._(SignalNode<T> _node) {
  factory Signal(T initialValue) => Signal._(
    SignalNode(
      flags: .mutable,
      currentValue: initialValue,
      pendingValue: initialValue,
    ),
  );

  T get value => _node.get();

  set value(T newValue) => _node.set(newValue);
}

extension type Computed<T>._(ComputedNode<T> _node) {
  factory Computed(T Function() getter) =>
      Computed._(ComputedNode(getter: (_) => getter(), flags: .none));

  T get value => _node.get();
}
// #endregion wrappers

void main() {
  // #region usage
  final count = Signal(0);
  final doubled = Computed(() => count.value * 2);
  var runs = 0; // #hide
  var cleanups = 0; // #hide

  // Reuse the public effect lifecycle with the custom value accessors.
  final stop = effect(() {
    runs++; // #hide
    print('Count: ${count.value}, Doubled: ${doubled.value}');
    return () => cleanups++; // #hide
  }); // Count: 0, Doubled: 0

  count.value = 2; // Count: 2, Doubled: 4
  assert(runs == 2 && cleanups == 1); // #hide
  stop();
  count.value = 3; // The stopped effect no longer runs.
  assert(runs == 2 && cleanups == 2); // #hide
  assert(doubled.value == 6); // #hide
  // #endregion usage
}
