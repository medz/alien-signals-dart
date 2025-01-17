import 'package:alien_signals/alien_signals.dart';

abstract interface class EffectScope implements Subscriber {}

abstract interface class Effect implements Dependency, Subscriber {
  void Function() get fn;
}

abstract interface class Signal<T> implements Dependency {
  abstract T currentValue;
  T call();
}

abstract interface class WriteableSignal<T> extends Signal<T> {
  @override
  T call([T value]);
}

abstract interface class Computed<T> extends Signal<T?> implements Subscriber {
  @override
  abstract T? currentValue;

  @override
  T call();

  bool notify();
}
