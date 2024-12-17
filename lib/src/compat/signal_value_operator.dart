import '../types.dart';

/// Extension that provides a value getter for signals.
///
/// Allows reading a signal's value using property syntax:
/// ```dart
/// final count = signal(0);
/// print(count.value); // Same as count.get()
/// ```
extension SignalValueGetter<T> on ISignal<T> {
  /// Gets the current value of the signal.
  ///
  /// This provides a more natural property-style syntax for reading signal values.
  /// Equivalent to calling [get()] directly.
  ///
  /// Returns the current value stored in the signal.
  T get value => get();
}

/// Extension that provides a value setter for writable signals.
///
/// Allows setting a signal's value using property syntax:
/// ```dart
/// final count = signal(0);
/// count.value = 1; // Same as count.set(1)
/// ```
extension SignalValueSetter<T> on IWritableSignal<T> {
  /// Gets the current value of the signal.
  ///
  /// This provides a more natural property-style syntax for reading signal values.
  /// Equivalent to calling [get()] directly.
  ///
  /// Returns the current value stored in the signal.
  T get value => get();

  /// Sets the value of the signal.
  ///
  /// This provides a more natural property-style syntax for writing signal values.
  /// Equivalent to calling [set(value)] directly.
  ///
  /// Parameter:
  ///   [value] - The new value to set
  set value(T value) => set(value);
}
