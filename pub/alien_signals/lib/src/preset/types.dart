abstract interface class EffectScope {
  void call();
}

abstract interface class Effect {
  void Function() get run;
  void call();
}

abstract interface class Signal<T> {
  T get untracked;
}

abstract interface class Computed<T> implements Signal<T?> {
  T Function(T? prevValue) get getter;
  T call();
}

abstract interface class WriteableSignal<T> implements Signal<T> {
  T call([T? value, bool setNulls = false]);
}
