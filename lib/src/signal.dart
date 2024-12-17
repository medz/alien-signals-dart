import 'effect.dart';
import 'system.dart';
import 'types.dart';

/// Creates a new [Signal] with the given initial [value].
///
/// A signal is a reactive primitive that holds a value and notifies subscribers
/// when that value changes.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// ```
Signal<T> signal<T>(T value) => Signal(value);

/// A mutable reactive signal that holds a value of type [T].
///
/// Signals are the basic unit of reactivity in the system. They hold a value
/// that can be read and written to, and automatically track dependencies and
/// notify subscribers when the value changes.
///
/// Implements [Dependency] to participate in the dependency tracking system and
/// [IWritableSignal] to provide read/write access to the contained value.
class Signal<T> implements Dependency, IWritableSignal<T> {
  /// Creates a new signal with the given [currentValue].
  Signal(this.currentValue);

  /// The current value stored in this signal.
  T currentValue;

  /// The ID of the last tracking operation that read this signal.
  @override
  int? lastTrackedId = 0;

  /// The head of the linked list of subscribers to this signal.
  @override
  Link? subs;

  /// The tail of the linked list of subscribers to this signal.
  @override
  Link? subsTail;

  /// Gets the current value of the signal.
  ///
  /// When called from within an effect or computed value, creates a dependency
  /// relationship so that the caller will be notified of future changes.
  ///
  /// Returns the current value stored in the signal.
  @override
  T get() {
    if (activeTrackId != 0 && lastTrackedId != activeTrackId) {
      final trackId = activeTrackId; // 保存当前的 trackId
      lastTrackedId = trackId;
      link(this, activeSub!);
    }
    return currentValue;
  }

  /// Sets a new value for the signal.
  ///
  /// If the new value is different from the current value, all subscribers
  /// will be notified of the change.
  ///
  /// Parameters:
  ///   [value] - The new value to set
  @override
  set(T value) {
    print('Signal set: current=$currentValue, new=$value');
    print('Signal subs: $subs'); // 检查是否有订阅者

    if (currentValue != (currentValue = value)) {
      print('Value changed'); // 确认值确实改变了

      final subs = this.subs;
      if (subs != null) {
        print('Has subscribers, calling propagate');
        propagate(subs);
      } else {
        print('No subscribers');
      }
    } else {
      print('Value not changed');
    }
  }
}
