import 'preset.dart';
import 'system.dart';

abstract interface class Signal<T> {
  T call([T Function()? updates]);
}

abstract interface class Computed<T> {
  T call();
}

abstract interface class Effect {
  void call();
}

abstract interface class EffectScope {
  void call();
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
ReactiveNode? getActiveSub() => activeSub;

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
ReactiveNode? setActiveSub(ReactiveNode? sub) {
  final prevSub = activeSub;
  activeSub = sub;
  return prevSub;
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
int getBatchDepth() => batchDepth;

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void startBatch() => ++batchDepth;

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void endBatch() {
  if (--batchDepth == 0) flush();
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
Signal<T> signal<T>(T initialValue) =>
    PresetSignal<T>(initialValue: initialValue);

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
Computed<T> computed<T>(T Function(T? previousValue) getter) =>
    PresetComputed(getter: getter);

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
Effect effect(void Function() fn) {
  final effect = PresetEffect(fn: fn), prevSub = setActiveSub(effect);
  if (prevSub != null) link(effect, prevSub, 0);
  try {
    fn();
    return effect;
  } finally {
    activeSub = prevSub;
  }
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
EffectScope effectScope(void Function() fn) {
  final scope = PresetEffectScope(), prevSub = setActiveSub(scope);
  if (prevSub != null) link(scope, prevSub, 0);
  try {
    fn();
    return scope;
  } finally {
    activeSub = prevSub;
  }
}
