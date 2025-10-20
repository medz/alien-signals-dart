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

ReactiveNode? getActiveSub() => activeSub;
ReactiveNode? setActiveSub(ReactiveNode? sub) {
  final prevSub = activeSub;
  activeSub = sub;
  return prevSub;
}

int getBatchDepth() => batchDepth;

void startBatch() => ++batchDepth;

void endBatch() {
  if (--batchDepth == 0) flush();
}

Signal<T> signal<T>(T initialValue) =>
    PresetSignal<T>(initialValue: initialValue);

Computed<T> computed<T>(T Function(T? previousValue) getter) =>
    PresetComputed(getter: getter);

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
