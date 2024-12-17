import 'system.dart';
import 'types.dart';

/// The currently active effect scope
///
/// Used to track the scope in which effects are being created
EffectScope? activeEffectScope;

/// Creates and returns a new [EffectScope].
///
/// Effect scopes are used to group and manage related effects together.
/// They allow for cleanup of effects when the scope is stopped.
///
/// Example:
/// ```dart
/// final scope = effectScope();
/// scope.run(() {
///   // Create effects here
/// });
/// scope.stop(); // Cleanup all effects
/// ```
EffectScope effectScope() => EffectScope();

/// A scope that groups and manages related effects.
///
/// Effect scopes allow effects to be grouped together and cleaned up as a unit.
/// When a scope is stopped, all effects created within it are cleaned up.
///
/// Implements [Subscriber] to participate in the dependency tracking system.
class EffectScope implements Subscriber, Notifiable {
  /// The head of the linked list of dependencies for this scope
  @override
  Link? deps;

  /// The tail of the linked list of dependencies for this scope
  @override
  Link? depsTail;

  /// The current state flags for this scope
  @override
  SubscriberFlags flags = SubscriberFlags.none;

  @override
  Notifiable? nextNotify;

  /// Notifies all effects in this scope to run if they are marked for execution.
  ///
  /// This is called when dependencies change and the scope needs to
  /// re-run its effects.
  @override
  void notify() {
    if (flags & SubscriberFlags.runInnerEffects != 0) {
      flags &= ~SubscriberFlags.runInnerEffects;
      for (var link = deps; link != null; link = link.nextDep) {
        final notifiable = switch (link.dep) {
          Notifiable notifiable => notifiable,
          _ => null,
        };
        notifiable?.notify();
      }
    }
  }

  /// Runs a function within this effect scope.
  ///
  /// While [fn] is running, this scope will be set as the active effect scope.
  /// Any effects created during the execution of [fn] will be associated with
  /// this scope.
  ///
  /// Parameters:
  ///   [fn] - The function to run within this scope
  ///
  /// Returns the value returned by [fn]
  T run<T>(T Function() fn) {
    final prevSub = activeEffectScope;
    activeEffectScope = this;
    try {
      return fn();
    } finally {
      activeEffectScope = prevSub;
    }
  }

  /// Stops this effect scope and cleans up all its effects.
  ///
  /// After calling stop, all effects created within this scope will be
  /// disconnected from their dependencies and will no longer execute.
  void stop() {
    startTrack(this);
    endTrack(this);
  }
}
