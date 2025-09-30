import 'preset.dart';

extension SignalDotValueGetter<T> on Signal<T> {
  @Deprecated('Use `call()` instead, remove in 2.0')
  T get value => call();
}

extension WritableSignalDotValueGetterSetter<T> on WritableSignal<T> {
  @Deprecated('Use `call()` instead, remove in 2.0')
  T get value => call();

  @Deprecated('Use `call(newValue, true)` instead, remove in 2.0')
  set value(T newValue) => call(newValue, true);
}
