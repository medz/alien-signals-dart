/// Represents a read-only signal that provides access to a value of type [T].
///
/// A signal is a reactive data source that can be subscribed to and will notify
/// subscribers when its value changes.
///
/// The [get] method returns the current value of the signal and establishes a
/// dependency tracking relationship with any active effect or computed value.
abstract interface class ISignal<T> {
  /// Gets the current value of the signal.
  ///
  /// When called from within an effect or computed value, creates a dependency
  /// relationship so that the caller will be notified of future changes.
  ///
  /// Returns the current value of type [T] stored in the signal.
  T get();
}

/// Represents a writable signal that provides both read and write access to a value of type [T].
///
/// A writable signal extends [ISignal] to also allow setting new values.
/// When a new value is set, all dependent computations and effects will be automatically
/// re-executed.
abstract interface class IWritableSignal<T> implements ISignal<T> {
  /// Sets a new value for the signal.
  ///
  /// When [value] is different from the current value, all dependent
  /// computations and effects will be notified and re-executed as needed.
  ///
  /// Parameter [value] is the new value to set for this signal.
  set(T value);
}

/// Represents an object that can be notified of changes and participate in a
/// notification chain.
///
/// This interface defines the contract for objects that need to receive
/// notifications and can be linked together in a chain of notifications,
/// typically used in reactive programming patterns.
abstract interface class Notifiable {
  /// Notifies this object that a change has occurred.
  ///
  /// This method is called when the object needs to be informed of a change
  /// and should handle the notification appropriately.
  void notify();

  /// Reference to the next object in the notification chain.
  ///
  /// When notifications need to be propagated through a series of objects,
  /// this property points to the next object that should receive the
  /// notification. May be null if this is the last object in the chain.
  Notifiable? nextNotify;
}
