import 'package:alien_signals/alien_signals.dart';

/// A scope for grouping related effects together.
abstract interface class EffectScope implements Subscriber {}

/// A side effect that runs when its dependencies change.
///
/// Effects are used to perform actions in response to signal changes,
/// such as updating the UI or making API calls.
abstract interface class Effect implements Dependency, Subscriber {
  /// The function to execute when dependencies change.
  void Function() get fn;
}

/// A reactive value that notifies subscribers when it changes.
///
/// Signals are the basic building blocks of the reactive system.
/// They hold values that can change over time and notify dependents
/// when changes occur.
abstract interface class Signal<T> implements Dependency {
  /// The current value of this signal.
  abstract T currentValue;

  /// Gets the current value of this signal.
  T call();
}

/// A signal that can be read from and written to.
///
/// WritableSignals extend regular signals by allowing their values
/// to be modified through the call operator.
abstract interface class WritableSignal<T> extends Signal<T> {
  /// Gets or sets the current value of this signal.
  @override
  T call([T value]);
}

/// A derived signal that computes its value from other signals.
///
/// Computed values automatically update when their dependencies change
/// and cache their results until needed again.
abstract interface class Computed<T> extends Signal<T?> implements Subscriber {
  /// The current computed value, may be null.
  @override
  abstract T? currentValue;

  /// Gets the current computed value.
  @override
  T call();

  /// Updates subscribers if the computed value has changed.
  bool notify();
}
