import 'package:alien_signals/alien_signals.dart';

import 'preset_effect_stop.dart';
import 'preset_system.dart';
import 'preset_types.dart';

/// Starts a batch update that prevents effects from being immediately executed when
/// signals change.
///
/// Any effects triggered during the batch will be queued and executed when [endBatch]
/// is called.
///
/// Example:
/// ```dart
/// startBatch();
/// signal1(1); // Effects won't run yet
/// signal2(2); // Effects still won't run
/// endBatch(); // Now all queued effects will execute
/// ```
void startBatch() {
  ++system.batchDepth;
}

/// Ends a batch update and processes any queued effects if this was the outermost
/// batch.
///
/// Should be called after [startBatch] when all batched updates are complete.
///
/// Example:
/// ```dart
/// startBatch();
/// try {
///   // Make multiple signal updates
///   signal1(1);
///   signal2(2);
/// } finally {
///   endBatch(); // Ensure effects are processed even if an error occurs
/// }
/// ```
void endBatch() {
  if ((--system.batchDepth) == 0) {
    system.processEffectNotifications();
  }
}

/// Temporarily pauses dependency tracking.
///
/// Any signal access between [pauseTracking] and [resumeTracking] will not be
/// tracked as a dependency.
///
/// Example:
/// ```dart
/// pauseTracking();
/// final value = signal(); // Not tracked as a dependency
/// resumeTracking();
/// ```
void pauseTracking() {
  system.pauseStack.add(system.activeSub);
  system.activeSub = null;
}

/// Resumes dependency tracking after it was paused with [pauseTracking].
///
/// Example:
/// ```dart
/// pauseTracking();
/// // Untracked operations
/// resumeTracking();
/// final value = signal(); // Now tracked as a dependency
/// ```
void resumeTracking() {
  try {
    system.activeSub = system.pauseStack.removeLast();
  } catch (_) {
    system.activeSub = null;
  }
}

/// Creates a new signal with the given initial value.
///
/// A signal is a reactive value that can be read and written to. When the value
/// changes, any computed values or effects that depend on it will automatically
/// update.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// effect(() {
///   print('Count is: ${count()}');
/// });
/// count(1); // Prints: Count is: 1
/// ```
WriteableSignal<T> signal<T>(T value) => _WriteableSignal(value);

class _WriteableSignal<T> with Dependency implements WriteableSignal<T> {
  _WriteableSignal(this.currentValue);

  @override
  T currentValue;

  @override
  T call([T? value]) {
    if (value is T) {
      if (currentValue != (currentValue = value)) {
        if (subs != null) {
          system.propagate(subs);
          if (system.batchDepth == 0) {
            system.processEffectNotifications();
          }
        }
      }

      return value;
    } else if (system.activeSub != null) {
      system.link(this, system.activeSub!);
    }

    return currentValue;
  }
}

/// Creates a new computed value that automatically updates when its dependencies change.
///
/// A computed value is a derived signal that calculates its value from other signals.
/// The getter function will be re-run automatically whenever any of the signals it
/// depends on change.
///
/// The getter function receives the previous computed value as an argument, allowing
/// you to optimize updates by comparing with the old value.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// final doubled = computed((prev) => count() * 2);
/// effect(() {
///   print('Doubled count is: ${doubled()}');
/// });
/// count(2); // Prints: Doubled count is: 4
/// ```
Computed<T> computed<T>(T Function(T? oldValue) getter) => _Computed(getter);

class _Computed<T> with Dependency, Subscriber implements Computed<T> {
  _Computed(this.getter);

  final T Function(T? oldValue) getter;

  @override
  T? currentValue;

  @override
  int flags = SubscriberFlags.computed | SubscriberFlags.dirty;

  @override
  T call() {
    if ((flags & (SubscriberFlags.dirty | SubscriberFlags.pendingComputed)) !=
        0) {
      system.processComputedUpdate(this, flags);
    }
    if (system.activeSub != null) {
      system.link(this, system.activeSub!);
    } else if (system.activeScope != null) {
      system.link(this, system.activeScope!);
    }

    return currentValue as T;
  }

  @override
  bool notify() {
    final oldValue = currentValue;
    final newValue = getter(oldValue);
    if (oldValue != newValue) {
      currentValue = newValue;
      return true;
    }
    return false;
  }
}

/// Creates a new effect that automatically runs when its dependencies change.
///
/// An effect is a side-effect that runs immediately and then re-runs whenever any of
/// the signals it accesses are modified. Effects are useful for performing tasks like
/// DOM updates, logging, or making API calls in response to state changes.
///
/// Returns an [EffectStop] that can be used to stop the effect from running.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// final stop = effect(() {
///   print('Count changed to: ${count()}');
/// }); // Prints: Count changed to: 0
///
/// count(1); // Prints: Count changed to: 1
/// count(2); // Prints: Count changed to: 2
///
/// stop(); // Effect is stopped and won't run anymore
/// count(3); // Nothing prints
/// ```
EffectStop<Effect> effect(void Function() fn) {
  final effect = _Effect(fn);
  if (system.activeSub != null) {
    system.link(effect, system.activeSub!);
  } else if (system.activeScope != null) {
    system.link(effect, system.activeScope!);
  }
  system.runEffect(effect);
  return EffectStop(effect);
}

class _Effect with Dependency, Subscriber implements Effect {
  _Effect(this.fn);

  @override
  final void Function() fn;

  @override
  int flags = SubscriberFlags.effect;
}

/// Creates a new effect scope that can be used to group and cleanup multiple effects.
///
/// An effect scope allows you to create multiple effects that can all be stopped
/// together by calling stop on the returned [EffectStop]. This is useful for
/// organizing related effects and ensuring they are all properly cleaned up.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// final name = signal('');
///
/// // Create a scope containing multiple effects
/// final stop = effectScope(() {
///   effect(() => print('Count is: ${count()}'));
///   effect(() => print('Name is: ${name()}'));
/// });
///
/// count(1); // Prints: Count is: 1
/// name('Alice'); // Prints: Name is: Alice
///
/// stop(); // All effects in scope are stopped
/// count(2); // Nothing prints
/// name('Bob'); // Nothing prints
/// ```
EffectStop<EffectScope> effectScope(void Function() fn) {
  final scope = _EffectScope();
  system.runEffectScope(scope, fn);
  return EffectStop(scope);
}

class _EffectScope with Subscriber implements EffectScope {
  @override
  int flags = SubscriberFlags.effect;
}
