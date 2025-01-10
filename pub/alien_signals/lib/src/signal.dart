import 'effect.dart';
import 'system.dart';
import 'types.dart';

/// {@template alien_signals.signal}
/// Creates a [Signal] with the given initial value.
///
/// Example:
/// ```dart
/// final mySignal = signal<int>(10);
/// print(mySignal.get()); // Outputs: 10
/// mySignal.set(20);
/// print(mySignal.get()); // Outputs: 20
/// ```
///
/// [T] is the type of the value held by the [Signal].
/// {@endtemplate}
Signal<T> signal<T>(T value) {
  return Signal(value);
}

/// A class that represents a reactive signal which holds a value of type [T].
///
/// The [Signal] class allows for reactive programming by tracking dependencies
/// and notifying subscribers when the value changes. It implements both
/// [Dependency] and [IWritableSignal] interfaces.
class Signal<T> implements Dependency, IWritableSignal<T> {
  /// {@macro alien_signals.signal}
  Signal(this.currentValue);

  /// The current value held by the signal.
  T currentValue;

  @override
  int? lastTrackedId = 0;

  @override
  Link? subs;

  @override
  Link? subsTail;

  @override
  T get() {
    if (activeTrackId != 0 && lastTrackedId != activeTrackId) {
      lastTrackedId = activeTrackId;
      link(this, activeSub!);
    }

    return this.currentValue;
  }

  @override
  set(T value) {
    if (currentValue != value) {
      currentValue = value;
      if (subs != null) {
        propagate(subs);
      }
    }
  }
}
