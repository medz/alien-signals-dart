import 'effect_scope.dart';
import 'system.dart';
import 'types.dart';

/// The currently active subscriber during tracking
Subscriber? activeSub;

/// The current tracking ID and last used tracking ID
int activeTrackId = 0, lastTrackId = 0;

/// Sets the active subscriber and tracking ID during dependency tracking.
///
/// Parameters:
///   [sub] - The subscriber to set as active
///   [trackId] - The tracking ID to set as active
void setActiveSub(Subscriber? sub, int trackId) {
  activeSub = sub;
  activeTrackId = trackId;
}

/// Generates the next tracking ID.
///
/// Returns an incrementing integer ID.
int nextTrackId() => ++lastTrackId;

/// Creates and runs an effect with the given function.
///
/// An effect is a reactive computation that automatically tracks dependencies
/// and re-runs when those dependencies change.
///
/// Parameters:
///   [fn] - The function to run as an effect
///
/// Returns the created [Effect] instance.
///
/// Example:
/// ```dart
/// final counter = signal(0);
/// effect(() => print(counter())); // Prints when counter changes
/// ```
Effect effect<T>(T Function() fn) {
  print('Creating effect');
  final e = Effect(fn);
  print('Effect created, running initial effect');
  e.run();
  print('Initial effect complete');

  return e;
}

/// A reactive effect that tracks dependencies and re-runs when they change.
///
/// Effects are the primary way to perform side effects in response to reactive
/// updates. They automatically track dependencies accessed during execution
/// and re-run when those dependencies change.
///
/// Type parameters:
///   [T] - The return type of the effect function
class Effect<T> implements IEffect, Dependency {
  /// Creates a new effect with the given function.
  ///
  /// The effect will be linked to the current active subscriber or effect scope
  /// if one exists.
  ///
  /// Parameters:
  ///   [fn] - The function to run when the effect executes
  Effect(this.fn) {
    if (activeTrackId != 0) {
      link(this, activeSub!);
    } else if (activeEffectScope != null) {
      link(this, activeEffectScope!);
    }
  }

  /// The function to run when this effect executes
  final T Function() fn;

  /// The head of this effect's dependency list
  @override
  Link? deps;

  /// The tail of this effect's dependency list
  @override
  Link? depsTail;

  /// The current state flags for this effect
  @override
  SubscriberFlags flags = SubscriberFlags.dirty;

  /// The ID of the last tracking operation that included this effect
  @override
  int? lastTrackedId;

  /// Reference to the next effect to notify in the notification queue
  @override
  Notifiable? nextNotify;

  /// The head of the subscriber list for this effect
  @override
  Link? subs;

  /// The tail of the subscriber list for this effect
  @override
  Link? subsTail;

  /// Notifies this effect that one of its dependencies has changed.
  ///
  /// This will cause the effect to re-run if necessary based on its current
  /// state flags.
  @override
  void notify() {
    final flags = this.flags;
    if ((flags & SubscriberFlags.dirty) != 0) {
      this.run();
      return;
    }
    if ((flags & SubscriberFlags.toCheckDirty) != 0) {
      if (checkDirty(this.deps!)) {
        this.run();
        return;
      } else {
        this.flags &= ~SubscriberFlags.toCheckDirty;
      }
    }
    if ((flags & SubscriberFlags.runInnerEffects) != 0) {
      this.flags &= ~SubscriberFlags.runInnerEffects;
      var link = this.deps;
      do {
        final dep = link?.dep;
        if (dep is Notifiable) {
          (dep as Notifiable).notify();
        }

        link = link?.nextDep;
      } while (link != null);
    }
  }

  /// Runs this effect's function with proper dependency tracking.
  ///
  /// Saves and restores the previous tracking context and ensures proper
  /// cleanup of tracking state.
  ///
  /// Returns the value returned by the effect function.
  T run() {
    final prevSub = activeSub, prevTrackId = activeTrackId;
    print('Effect run: prevSub=$prevSub, prevTrackId=$prevTrackId');

    final currentTrackId = nextTrackId();
    setActiveSub(this, currentTrackId);
    print('New trackId: $currentTrackId');
    startTrack(this);

    try {
      return fn();
    } finally {
      endTrack(this);
      print('Effect tracking complete');
      // 最后才重置 tracking 状态
      setActiveSub(prevSub, prevTrackId);
    }
  }

  void stop() {
    startTrack(this);
    endTrack(this);
  }
}
