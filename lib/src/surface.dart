import 'package:alien_signals/preset.dart'
    show
        setActiveSub,
        activeSub,
        link,
        stop,
        SignalNode,
        ComputedNode,
        EffectNode;
import 'package:alien_signals/system.dart' show ReactiveFlags, ReactiveNode;

/// A reactive signal that holds a value of type [T].
///
/// Signals are the foundation of the reactive system. They are observable
/// values that notify their dependents when their value changes.
///
/// Use the [call] method to read the current value of the signal.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// print(count()); // prints: 0
/// ```
abstract interface class Signal<T> {
  /// Reads the current value of the signal.
  ///
  /// When called within a reactive context (like inside a [computed] or [effect]),
  /// this will establish a dependency relationship.
  T call();
}

/// A reactive signal that can be both read and written.
///
/// WritableSignal extends [Signal] to provide write capabilities.
/// It allows updating the signal's value, which will trigger updates
/// to all dependent computations and effects.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// count.set(5); // sets value to 5
/// print(count()); // prints: 5
/// ```
abstract interface class WritableSignal<T> implements Signal<T> {
  /// Sets the value of this writable signal.
  ///
  /// This will update the signal's value and trigger notifications to all
  /// dependent computations and effects.
  ///
  /// Example:
  /// ```dart
  /// final count = signal(0);
  /// count.set(5); // sets value to 5
  /// print(count()); // prints: 5
  /// ```
  ///
  /// - Parameter [value]: The new value to set.
  void set(T value);
}

/// A reactive computed value that derives from other signals.
///
/// Computed values automatically recalculate when their dependencies change.
/// They are lazily evaluated, meaning they only recompute when accessed
/// and their dependencies have changed.
///
/// Computed values are read-only and cannot be directly set.
///
/// Example:
/// ```dart
/// final count = signal(2);
/// final doubled = computed((prev) => count() * 2);
/// print(doubled()); // prints: 4
/// count(3);
/// print(doubled()); // prints: 6
/// ```
abstract interface class Computed<T> implements Signal<T> {}

/// A reactive effect that runs side effects in response to signal changes.
///
/// Effects automatically track their dependencies and re-run when any
/// dependency changes. They are useful for performing side effects like
/// DOM updates, logging, or API calls.
///
/// Use the [call] method to stop the effect and clean up its subscriptions.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// final dispose = effect(() {
///   print('Count is: ${count()}');
/// });
/// // Later, stop the effect:
/// dispose();
/// ```
abstract interface class Effect {
  /// Stops this effect and removes it from the reactive system.
  ///
  /// After calling this method, the effect will no longer respond to
  /// changes in its dependencies.
  void call();
}

/// A scope that manages a collection of effects.
///
/// EffectScope provides a way to group multiple effects together
/// and dispose of them all at once. Any effects created within
/// the scope will be automatically linked to it.
///
/// Use the [call] method to stop all effects within this scope.
///
/// Example:
/// ```dart
/// final scope = effectScope(() {
///   effect(() => print('Effect 1'));
///   effect(() => print('Effect 2'));
/// });
/// // Later, stop all effects in the scope:
/// scope();
/// ```
abstract interface class EffectScope {
  /// Stops all effects within this scope.
  ///
  /// This will recursively stop all child effects and nested scopes,
  /// cleaning up all reactive subscriptions.
  void call();
}

/// Creates a writable signal with the given initial value.
///
/// Signals are the most basic reactive primitive. They hold a value
/// and notify their dependents when that value changes.
///
/// The returned signal can be called without arguments to read its value,
/// or with an argument to write a new value.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// print(count()); // reads: 0
/// count.set(5);   // writes: 5
/// print(count()); // reads: 5
/// ```
///
/// - Parameter [initialValue]: The initial value of the signal.
/// - Returns: A [WritableSignal] that can be read and written.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
WritableSignal<T> signal<T>(T initialValue) {
  return _SignalImpl(
      flags: ReactiveFlags.mutable,
      currentValue: initialValue,
      pendingValue: initialValue);
}

/// Creates a computed value that derives from other signals.
///
/// Computed values automatically track the signals they depend on
/// and recalculate when those dependencies change. They are lazily
/// evaluated and cache their results until dependencies change.
///
/// The getter function receives the previous computed value as its
/// parameter (or `null` on first computation), which can be useful
/// for incremental computations.
///
/// Example:
/// ```dart
/// final firstName = signal('John');
/// final lastName = signal('Doe');
/// final fullName = computed((prev) {
///   return '${firstName()} ${lastName()}';
/// });
/// print(fullName()); // "John Doe"
/// lastName('Smith');
/// print(fullName()); // "John Smith"
/// ```
///
/// - Parameter [getter]: A function that computes the value. Receives the
///   previous value as a parameter (null on first run).
/// - Returns: A [Computed] that automatically updates when dependencies change.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
Computed<T> computed<T>(T Function(T?) getter) {
  return _ComputedImpl(getter: getter, flags: ReactiveFlags.none);
}

/// Creates an effect that runs whenever its dependencies change.
///
/// Effects are functions that run side effects in response to reactive
/// state changes. They automatically track any signals accessed during
/// execution and re-run when those signals change.
///
/// The effect runs immediately upon creation and then again whenever
/// its dependencies change.
///
/// The returned [Effect] can be called to stop the effect and clean up
/// its subscriptions.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// final messages = <String>[];
///
/// final dispose = effect(() {
///   messages.add('Count is: ${count()}');
/// });
///
/// count(1); // Effect runs again
/// count(2); // Effect runs again
///
/// dispose(); // Stop the effect
/// count(3); // Effect no longer runs
/// ```
///
/// - Parameter [fn]: The function to run as an effect. Will be executed
///   immediately and re-executed when dependencies change.
/// - Returns: An [Effect] that can be called to stop it.
Effect effect(void Function() fn) {
  final e = _EffectImpl(
    fn: fn,
    flags: ReactiveFlags.watching | ReactiveFlags.recursedCheck,
  );
  final prevSub = setActiveSub(e);
  if (prevSub != null) link(e, prevSub, 0);
  try {
    e.fn();
  } finally {
    activeSub = prevSub;
    e.flags &= ~ReactiveFlags.recursedCheck;
  }
  return e;
}

/// Creates a scope for managing multiple effects.
///
/// Any effects created within the provided function will be linked
/// to this scope. When the scope is disposed, all linked effects
/// are automatically stopped.
///
/// This is useful for organizing and cleaning up related effects,
/// such as when a component is unmounted or a feature is disabled.
///
/// Example:
/// ```dart
/// final count = signal(0);
///
/// final scope = effectScope(() {
///   effect(() => print('Effect 1: ${count()}'));
///   effect(() => print('Effect 2: ${count() * 2}'));
///
///   // Nested scopes are also supported
///   effectScope(() {
///     effect(() => print('Nested effect: ${count() * 3}'));
///   });
/// });
///
/// count(1); // All effects run
///
/// scope(); // Stop all effects in this scope
/// count(2); // No effects run
/// ```
///
/// - Parameter [fn]: A function that creates effects. All effects created
///   within this function will be linked to the scope.
/// - Returns: An [EffectScope] that can be called to stop all contained effects.
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
EffectScope effectScope(void Function() fn) {
  final e = _EffectScopeImpl(flags: ReactiveFlags.none);
  final prevSub = setActiveSub(e);
  if (prevSub != null) link(e, prevSub, 0);

  try {
    fn();
  } finally {
    activeSub = prevSub;
  }
  return e;
}

final class _SignalImpl<T> extends SignalNode<T> implements WritableSignal<T> {
  _SignalImpl(
      {required super.flags,
      required super.currentValue,
      required super.pendingValue});

  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  T call() => get();
}

final class _ComputedImpl<T> extends ComputedNode<T> implements Computed<T> {
  _ComputedImpl({required super.flags, required super.getter});

  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  T call() => get();
}

final class _EffectImpl extends EffectNode implements Effect {
  _EffectImpl({required super.flags, required super.fn});

  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  void call() => stop(this);
}

class _EffectScopeImpl extends ReactiveNode implements EffectScope {
  _EffectScopeImpl({required super.flags});

  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  void call() => stop(this);
}
