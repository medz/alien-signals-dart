import 'effect.dart';
import 'system.dart';
import 'types.dart';

/// Creates a new computed value that derives from other reactive values.
///
/// The [getter] function is used to calculate the computed value. It receives the
/// previous value (if any) as an argument and should return the new computed value.
/// The getter will be re-run automatically when any of its dependencies change.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// final doubleCount = computed((prev) => count.get() * 2);
/// ```
Computed<T> computed<T>(T Function(T? value) getter) => Computed(getter);

/// A computed value that automatically updates when its dependencies change.
///
/// Computed values are derived from other reactive values (signals or other computed values).
/// They cache their result and only recalculate when their dependencies change.
///
/// Implements both [IComputed] to participate in the dependency graph and [ISignal] to
/// be usable as a dependency for other computed values and effects.
class Computed<T> implements IComputed, ISignal<T> {
  /// Creates a new computed value with the given [getter] function.
  Computed(this.getter);

  /// Function used to calculate this computed value.
  ///
  /// Receives the previous value as an argument and returns the new computed value.
  final T Function(T? _) getter;

  /// The cached result of the last computation.
  T? cachedValue;

  /// The head of the linked list of dependencies.
  @override
  Link? deps;

  /// The tail of the linked list of dependencies.
  @override
  Link? depsTail;

  /// Current state flags for this computed value.
  @override
  SubscriberFlags flags = SubscriberFlags.dirty;

  /// ID of the last tracking operation that read this computed value.
  @override
  int? lastTrackedId;

  /// The head of the linked list of subscribers.
  @override
  Link? subs;

  /// The tail of the linked list of subscribers.
  @override
  Link? subsTail;

  /// Current version number, incremented when the value changes.
  @override
  int version = 0;

  /// Gets the current value of this computed value.
  ///
  /// Will trigger a recomputation if the value is dirty or needs checking.
  /// Establishes dependency tracking when called from within an effect or
  /// another computed value.
  ///
  /// Returns the current computed value.
  @override
  T get() {
    final f = flags;
    if (f & SubscriberFlags.dirty != SubscriberFlags.none) {
      update();
    } else if (f & SubscriberFlags.toCheckDirty != SubscriberFlags.none) {
      if (deps != null && checkDirty(deps!)) {
        update();
      } else {
        flags &= ~SubscriberFlags.toCheckDirty;
      }
    }

    if (activeTrackId != 0 && lastTrackedId != activeTrackId) {
      lastTrackedId = activeTrackId;
      link(this, activeSub!).version = version;
    }

    return cachedValue!;
  }

  /// Updates the computed value by running the getter function.
  ///
  /// Handles dependency tracking during the computation and updates the
  /// cached value and version if the result changes.
  ///
  /// Returns true if the value actually changed, false otherwise.
  @override
  bool update() {
    final prevSub = activeSub, prevTrackId = activeTrackId;
    setActiveSub(this, nextTrackId());
    startTrack(this);

    final oldValue = cachedValue;
    late final T newValue;

    try {
      newValue = getter(oldValue);
    } finally {
      setActiveSub(prevSub, prevTrackId);
      endTrack(this);
    }

    if (!identical(oldValue, newValue)) {
      cachedValue = newValue;
      version++;
      return true;
    }

    return false;
  }
}
