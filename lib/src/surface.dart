/// @docImport 'preset.dart';
library;

import 'preset.dart'
    show
        setActiveSub,
        activeSub,
        runDepth,
        link,
        stop,
        hasChildEffect,
        SignalNode,
        ComputedNode,
        EffectNode,
        EffectScopeNode,
        EffectCallback;

import 'package:alien_signals/system.dart' show ReactiveFlags;

/// A reactive value of type [T].
///
/// Use [call] to read the value and track it inside a [computed] or [effect].
///
/// {@example /example/main.dart#basic}
abstract interface class Signal<T> {
  /// Reads the current value of the signal.
  ///
  /// When called within a reactive context (like inside a [computed] or [effect]),
  /// this will establish a dependency relationship.
  T call();
}

/// A reactive value that can be read and written.
///
/// Use [call] to read the value and [set] to update it.
///
/// {@example /example/main.dart#basic}
abstract interface class WritableSignal<T> implements Signal<T> {
  /// Sets this signal to [value].
  ///
  /// Values are compared with [identical], not `==`. Setting the same object
  /// does not notify dependents; after mutating a list or map in place, use
  /// [trigger] with a read of this signal to notify readers.
  ///
  /// {@example /example/trigger.dart#trigger}
  void set(T value);
}

/// A cached, read-only value derived from other signals.
///
/// The getter runs lazily when the value is read and its dependencies have
/// changed. See [computed] for error caching and previous-value semantics.
///
/// {@example /example/computed.dart#computed}
abstract interface class Computed<T> implements Signal<T> {}

/// A side effect that tracks synchronous reads of reactive values.
///
/// Use [call] to stop the effect and run its final cleanup.
/// See [effect] for dependency tracking and cleanup ordering.
///
/// {@example /example/effect_cleanup.dart#cleanup}
abstract interface class Effect {
  /// Stops this effect and removes it from the reactive system.
  ///
  /// After calling this method, the effect will no longer respond to
  /// changes in its dependencies.
  void call();
}

/// A group of effects and nested scopes with a shared lifetime.
///
/// Use [call] to stop everything created synchronously within the scope.
///
/// {@example /example/effect_scope.dart#scope}
abstract interface class EffectScope {
  /// Stops all effects within this scope.
  ///
  /// This will recursively stop all child effects and nested scopes,
  /// cleaning up all reactive subscriptions.
  void call();
}

/// Creates a writable signal containing [initialValue].
///
/// Call the returned signal to read its value, and use [WritableSignal.set]
/// to write a new value. Changes use [identical] rather than `==`; mutating
/// the same object in place requires [trigger] to notify readers.
///
/// {@example /example/main.dart#basic}
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
WritableSignal<T> signal<T>(T initialValue) {
  return _SignalImpl(
    flags: .mutable,
    currentValue: initialValue,
    pendingValue: initialValue,
  );
}

/// Creates a cached value derived by [getter] from other signals.
///
/// Synchronous reads inside [getter] become dependencies. The getter runs
/// lazily on the first read and when a subsequent read needs an updated value.
/// Its argument is the previous successful value, or `null` before any success.
///
/// Getter errors are cached and rethrown until a tracked dependency changes.
/// A successful retry clears the cached error; a failed run does not replace
/// the previous successful value.
///
/// {@example /example/computed.dart#computed}
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
Computed<T> computed<T>(T Function(T?) getter) {
  return _ComputedImpl(getter: getter, flags: .none);
}

/// Runs [fn] immediately and again when its tracked dependencies change.
///
/// The callback may return a cleanup function synchronously. Cleanup runs
/// before the next execution and when the effect is stopped. Cleanup reads
/// are not tracked. Nested effects and scopes stop before their parent's
/// cleanup runs.
///
/// Dependency tracking and ownership of nested effects and scopes are
/// synchronous. Reads or effects created after an `await` are not tracked
/// or owned by this effect.
///
/// Call the returned [Effect] to stop it and run its final cleanup.
///
/// {@example /example/effect_cleanup.dart#cleanup}
Effect effect<T>(EffectCallback<T> fn) {
  // dart format off
  final e = _EffectImpl(fn: fn, flags: 6 /* ReactiveFlags.watching | ReactiveFlags.recursedCheck */ as ReactiveFlags),// dart format on
      prevSub = setActiveSub(e);
  if (prevSub != null) {
    link(e, prevSub, 0);
    prevSub.flags |= hasChildEffect;
  }
  try {
    ++runDepth;
    e.cleanup = e.runEffect();
    return e;
  } finally {
    --runDepth;
    activeSub = prevSub;
    e.flags &= -5 /*~ ReactiveFlags.recursedCheck */;
  }
}

/// Runs [fn] in a scope that groups effects for disposal.
///
/// Call the returned [EffectScope] to stop its effects and nested scopes.
/// Only effects and scopes created synchronously within [fn] are owned;
/// those created after an `await` need their own disposal handle.
///
/// {@example /example/effect_scope.dart#scope}
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
EffectScope effectScope(void Function() fn) {
  final e = _EffectScopeImpl(flags: .mutable), prevSub = setActiveSub(e);
  if (prevSub != null) {
    link(e, prevSub, 0);
    prevSub.flags |= hasChildEffect;
  }
  try {
    fn();
    return e;
  } finally {
    activeSub = prevSub;
  }
}

final class _SignalImpl<T>({
  required super.flags,
  required super.currentValue,
  required super.pendingValue,
}) extends SignalNode<T> implements WritableSignal<T> {
  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  T call() => get();
}

final class _ComputedImpl<T>({required super.flags, required super.getter})
    extends ComputedNode<T>
    implements Computed<T> {
  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  T call() => get();
}

final class _EffectImpl<T>({required super.flags, required super.fn})
    extends EffectNode<T>
    implements Effect {
  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  void call() => stop(this);
}

class _EffectScopeImpl({required super.flags})
    extends EffectScopeNode
    implements EffectScope {
  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  void call() => stop(this);
}
