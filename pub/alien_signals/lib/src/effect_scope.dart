import 'effect.dart';
import 'system.dart';

/// The currently active effect scope, if any.
EffectScope? activeEffectScope;

/// The track ID associated with the currently active effect scope.
int activeScopeTrackId = 0;

/// Sets the currently active effect scope and its associated track ID.
///
/// This function updates the global variables [activeEffectScope] and
/// [activeScopeTrackId] with the provided [scope] and [trackId] respectively.
///
/// - Parameters:
///   - scope: The effect scope to set as active.
///   - trackId: The track ID associated with the effect scope.
void setActiveScope(EffectScope? scope, int trackId) {
  activeEffectScope = scope;
  activeScopeTrackId = trackId;
}

/// Executes a function without tracking the current effect scope.
///
/// This function temporarily sets the [activeEffectScope] and [activeScopeTrackId]
/// to `null` and `0` respectively, executes the provided function [fn], and then
/// restores the previous values of [activeEffectScope] and [activeScopeTrackId].
///
/// - Parameter fn: The function to execute without tracking the current effect scope.
/// - Returns: The result of the executed function [fn].
T untrackScope<T>(T Function() fn) {
  final prevSub = activeEffectScope;
  final prevTrackId = activeScopeTrackId;
  setActiveScope(null, 0);
  try {
    return fn();
  } finally {
    setActiveScope(prevSub, prevTrackId);
  }
}

/// {@template alien_signals.effect_scope}
/// Creates a new [EffectScope] instance.
///
/// This function initializes and returns a new instance of the [EffectScope] class,
/// which implements the [IEffect] interface. The new effect scope can be used to
/// manage and track dependencies and their notifications.
///
/// - Returns: A new instance of the [EffectScope] class.
///
/// ```dart
/// final scope = effectScope();
/// scope.run(() {
///   // Your code here
/// });
/// ```
/// {@endtemplate}
EffectScope effectScope() {
  return EffectScope();
}

/// Executes a [effect] within the context of this effect scope.
///
/// This method temporarily sets the [activeEffectScope] and [activeScopeTrackId]
/// to this effect scope and its associated track ID, executes the provided function [fn],
/// and then restores the previous values of [activeEffectScope] and [activeScopeTrackId].
///
/// - Parameter fn: The function to execute within the context of this effect scope.
/// - Returns: The result of the executed function [fn].
class EffectScope implements IEffect {
  @override
  Link? deps;

  @override
  Link? depsTail;

  @override
  SubscriberFlags flags = SubscriberFlags.none;

  @override
  IEffect? nextNotify;

  /// The track ID associated with this effect scope.
  ///
  /// This ID is used to uniquely identify the effect scope within the system.
  int trackId = nextTrackId();

  @override
  void notify() {
    if ((flags & SubscriberFlags.innerEffectsPending) != 0) {
      flags &= ~SubscriberFlags.innerEffectsPending;
      runInnerEffects(deps);
    }
  }

  T run<T>(T Function() fn) {
    final prevSub = activeEffectScope;
    final prevTrackId = activeScopeTrackId;
    activeEffectScope = this;
    activeScopeTrackId = trackId;
    try {
      return fn();
    } finally {
      activeEffectScope = prevSub;
      activeScopeTrackId = prevTrackId;
    }
  }

  /// Stops the current effect scope.
  ///
  /// This method stops tracking dependencies for the current effect scope by
  /// calling [startTrack] and [endTrack] with this effect scope.
  ///
  /// Example usage:
  /// ```dart
  /// final scope = effectScope();
  /// scope.run(() {
  ///   // Your code here
  /// });
  /// scope.stop();
  /// ```
  void stop() {
    startTrack(this);
    endTrack(this);
  }
}
