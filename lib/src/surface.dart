import 'package:alien_signals/preset.dart'
    show
        setActiveSub,
        activeSub,
        link,
        stop,
        SignalNode,
        ComputedNode,
        EffectNode;
import 'package:alien_signals/src/system.dart';
import 'package:alien_signals/system.dart' show ReactiveFlags;

abstract interface class Signal<T> {
  T call();
}

abstract interface class WritableSignal<T> implements Signal<T> {
  @override
  T call([T? value, bool nulls]);
}

abstract interface class Computed<T> implements Signal<T> {}

abstract interface class Effect {
  void call();
}

abstract interface class EffectScope {
  void call();
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
WritableSignal<T> signal<T>(T initialValue) {
  return _SignalImpl(
      flags: ReactiveFlags.mutable,
      currentValue: initialValue,
      pendingValue: initialValue);
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
Computed<T> computed<T>(T Function(T?) getter) {
  return _ComputedImpl(getter: getter, flags: ReactiveFlags.none);
}

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
  T call([T? value, bool nulls = false]) {
    if (value != null || nulls) {
      set(value as T);
      return value;
    }
    return get();
  }
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
  void call() {
    stop(this);
  }
}

class _EffectScopeImpl extends ReactiveNode implements EffectScope {
  _EffectScopeImpl({required super.flags});

  @override
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  void call() {
    stop(this);
  }
}
