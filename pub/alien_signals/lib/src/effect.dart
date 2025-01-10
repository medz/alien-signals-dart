import 'effect_scope.dart';
import 'system.dart';

/// The currently active subscriber.
Subscriber? activeSub;

/// Sets the currently active subscriber.
///
/// This function updates the global `activeSub` variable to the provided `sub`.
///
/// @param sub The subscriber to set as active.
void setActiveSub(Subscriber? sub) {
  activeSub = sub;
}

/// Executes a function without tracking dependencies.
///
/// This function temporarily sets the active subscriber and track ID to null and 0 respectively,
/// executes the provided function, and then restores the previous subscriber and track ID.
///
/// @param fn The function to execute without tracking.
/// @returns The result of the executed function.
///
/// Example:
/// ```dart
/// int result = untrack(() {
///   // Code to execute without tracking dependencies
///   return count.get();
/// });
/// ```
T untrack<T>(T Function() fn) {
  final prevSub = activeSub;
  setActiveSub(null);
  try {
    return fn();
  } finally {
    setActiveSub(prevSub);
  }
}

/// {@template alien_signals.effect}
/// Creates and runs an effect.
///
/// This function creates an `Effect` object with the provided function `fn` and immediately runs it.
///
/// @param fn The function to be executed as an effect.
/// @returns The created `Effect` object.
///
/// Example:
/// ```dart
/// final a = signal(0);
/// effect(() {
///   print(a.get());
/// });
///
/// a.set(1);
/// ```
/// {@endtemplate}
Effect<T> effect<T>(T Function() fn) {
  return Effect(fn)..run();
}

/// Represents an effect that can be tracked and notified of changes.
///
/// The `Effect` class implements the `IEffect` and `Dependency` interfaces.
/// It is responsible for running a provided function `fn` and managing its dependencies.
/// When dependencies change, the effect is notified and re-executed if necessary.
class Effect<T> implements IEffect, Dependency {
  /// {@macro alien_signals.effect}
  Effect(this.fn) {
    if (activeSub != null) {
      link(this, activeSub!);
    } else if (activeEffectScope != null) {
      link(this, activeEffectScope!);
    }
  }

  /// The function to be executed as an effect.
  final T Function() fn;

  @override
  Link? deps;

  @override
  Link? depsTail;

  @override
  SubscriberFlags flags = SubscriberFlags.dirty;

  @override
  IEffect? nextNotify;

  @override
  Link? subs;

  @override
  Link? subsTail;

  @override
  void notify() {
    final flags = this.flags;
    if (flags & (SubscriberFlags.toCheckDirty | SubscriberFlags.dirty) != 0 &&
        isDirty(this, flags)) {
      run();
      return;
    }

    if ((flags & SubscriberFlags.innerEffectsPending) != 0) {
      this.flags = flags & ~SubscriberFlags.innerEffectsPending;
      runInnerEffects(deps);
    }
  }

  /// Runs the effect.
  ///
  /// This method sets the current effect as the active subscriber and track ID,
  /// starts tracking dependencies, executes the effect function, and then
  /// restores the previous subscriber and track ID.
  ///
  /// @returns The result of the effect function.
  T run() {
    final prevSub = activeSub;
    setActiveSub(this);
    startTrack(this);
    try {
      return fn();
    } finally {
      setActiveSub(prevSub);
      endTrack(this);
    }
  }

  /// Stops the effect.
  ///
  /// This method starts and ends tracking for the current effect, effectively
  /// stopping it from being notified of changes.
  ///
  /// Example:
  /// ```dart
  /// final count = signal(0);
  /// final e = effect(() => print(count.get())); // Prints: 0
  ///
  /// count.set(1); // Prints 1
  ///
  /// e.stop(); // Stop the effect.
  /// count.set(2); // No response
  /// ```
  void stop() {
    startTrack(this);
    endTrack(this);
  }
}
