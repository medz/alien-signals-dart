import '../types.dart';

/// Extension that adds function call syntax for reading signal values.
///
/// Allows signals to be called like functions to get their current value:
/// ```dart
/// final count = signal(0);
/// print(count()); // Prints current value
/// ```
extension SignalCallGetter<T> on ISignal<T> {
  /// Gets the current value of the signal using function call syntax.
  ///
  /// Returns the current value stored in the signal.
  T call() => get();
}

/// Extension that adds function call syntax for reading and writing signal values.
///
/// Allows writable signals to be called like functions to get or set their value:
/// ```dart
/// final count = signal<>(0);
/// print(count());     // Get value
/// count(1);          // Set value
/// count(null, true); // Set null value
/// ```
extension SignalCall<T> on IWritableSignal<T> {
  /// Gets or sets the signal value using function call syntax.
  ///
  /// If called with no arguments or with null and set=false, returns the current value.
  /// Otherwise sets the signal to the provided value.
  ///
  /// Parameters:
  ///   [value] - Optional new value to set
  ///   [set] - If true, forces setting the value even if null
  ///
  /// Returns the current value if getting, or the new value if setting.
  T call([T? value, bool set = false]) {
    if (value == null && !set) {
      return get();
    }

    this.set(value as T);
    return value;
  }
}
