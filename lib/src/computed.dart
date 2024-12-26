import 'effect.dart';
import 'effect_scope.dart';
import 'system.dart';
import 'types.dart';

/// {@template alien_signals.computed}
/// Creates a computed read-only signal
///
/// - [getter] A function that computes the value of the signal. It receives the old value as a parameter and returns the new value.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// final total = computed<int>((oldValue) {
///   return (oldValue ?? 0) + count.get();
/// });
/// ```
/// {@endtemplate}
Computed<T> computed<T>(T Function(T? oldValue) getter) {
  return Computed<T>(getter);
}

/// The [computed] returns class.
class Computed<T> implements IComputed, ISignal<T> {
  /// {@macro alien_signals.computed}
  Computed(this.getter);

  /// A function that computes the value of the signal.
  /// It receives the old value as a parameter and returns the new value.
  final T Function(T? oldValue) getter;

  /// The current value of the computed signal.
  T? currentValue;

  @override
  Link? deps;

  @override
  Link? depsTail;

  @override
  SubscriberFlags flags = SubscriberFlags.dirty;

  @override
  int? lastTrackedId = 0;

  @override
  Link? subs;

  @override
  Link? subsTail;

  @override
  T get() {
    if ((flags & SubscriberFlags.dirty) != 0) {
      if (update() && subs != null) {
        shallowPropagate(subs);
      }
    } else if ((flags & SubscriberFlags.toCheckDirty) != 0) {
      if (checkDirty(deps)) {
        if (update() && subs != null) {
          shallowPropagate(subs);
        }
      } else {
        flags &= ~SubscriberFlags.toCheckDirty;
      }
    }

    if (activeTrackId != 0) {
      if (lastTrackedId != activeTrackId) {
        lastTrackedId = activeTrackId;
        link(this, activeSub!);
      }
    } else if (activeScopeTrackId != 0) {
      if (lastTrackedId != activeScopeTrackId) {
        lastTrackedId = activeScopeTrackId;
        link(this, activeEffectScope!);
      }
    }

    return currentValue as T;
  }

  @override
  bool update() {
    final prevSub = activeSub;
    final prevTrackId = activeTrackId;
    setActiveSub(this, nextTrackId());
    startTrack(this);

    try {
      final oldValue = currentValue;
      final newValue = getter(oldValue);
      if (oldValue != newValue) {
        this.currentValue = newValue;
        return true;
      }

      return false;
    } finally {
      setActiveSub(prevSub, prevTrackId);
      endTrack(this);
    }
  }
}
