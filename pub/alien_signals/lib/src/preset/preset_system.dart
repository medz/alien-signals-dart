import 'package:alien_signals/alien_signals.dart';

import 'preset_types.dart';

/// The singleton instance of the reactive system.
final system = PresetSystem();

/// A concrete implementation of the ReactiveSystem for handling
/// computed values, effects and reactive scopes.
class PresetSystem extends ReactiveSystem<Computed> {
  /// Currently active subscriber being tracked
  Subscriber? activeSub;

  /// Currently active effect scope
  Subscriber? activeScope;

  /// Tracks nested batch operation depth
  int batchDepth = 0;

  /// Stack for temporarily pausing subscribers during operations
  final pauseStack = <Subscriber?>[];

  @override
  bool notifyEffect(Subscriber effect) {
    if (effect is EffectScope) {
      return notifyEffectScope(effect);
    }

    final flags = effect.flags;
    if ((flags & SubscriberFlags.dirty) != 0 ||
        ((flags & SubscriberFlags.pendingComputed) != 0 &&
            updateDirtyFlag(effect, flags))) {
      runEffect(effect as Effect);
    } else {
      processPendingInnerEffects(effect, effect.flags);
    }
    return true;
  }

  @override
  bool updateComputed(Computed computed) {
    final prevSub = activeSub;
    activeSub = computed;
    startTracking(computed);
    try {
      return computed.notify();
    } finally {
      activeSub = prevSub;
      endTracking(computed);
    }
  }

  /// Executes an effect's function while properly tracking dependencies.
  ///
  /// This method:
  /// 1. Saves and updates the currently active subscriber
  /// 2. Starts dependency tracking for the effect
  /// 3. Runs the effect's function
  /// 4. Restores the previous active subscriber
  /// 5. Ends dependency tracking
  ///
  /// [effect] The effect to run
  void runEffect(Effect effect) {
    final prevSub = activeSub;
    activeSub = effect;
    startTracking(effect);
    try {
      effect.fn();
    } finally {
      activeSub = prevSub;
      endTracking(effect);
    }
  }

  /// Executes a function within an effect scope while tracking dependencies.
  ///
  /// This method:
  /// 1. Saves the current active scope
  /// 2. Sets the provided scope as active
  /// 3. Starts dependency tracking for the scope
  /// 4. Runs the provided function
  /// 5. Restores the previous active scope
  /// 6. Ends dependency tracking
  ///
  /// [scope] The effect scope to run within
  /// [fn] The function to execute in the scope
  void runEffectScope(EffectScope scope, void Function() fn) {
    final prevSub = activeScope;
    activeScope = scope;
    startTracking(scope);
    try {
      fn();
    } finally {
      activeScope = prevSub;
      endTracking(scope);
    }
  }

  /// Processes a notification for an EffectScope, handling any pending effects.
  ///
  /// This method checks if the scope has any pending effects that need to be
  /// processed. If there are pending effects, it will process them and return
  /// true. Otherwise, it returns false indicating no effects needed processing.
  ///
  /// [scope] The effect scope to process notifications for
  ///
  /// Returns true if pending effects were processed, false otherwise
  bool notifyEffectScope(EffectScope scope) {
    final flags = scope.flags;
    if ((flags & SubscriberFlags.pendingEffect) != 0) {
      processPendingInnerEffects(scope, scope.flags);
      return true;
    }
    return false;
  }
}
