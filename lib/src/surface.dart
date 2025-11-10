import 'package:alien_signals/preset.dart';
import 'package:alien_signals/system.dart' show ReactiveFlags;

abstract interface class Signal<T> {
  T call();
}

abstract interface class WritableSignal<T> implements Signal<T> {
  @override
  T call([T? value, bool nulls]);
}

abstract interface class Computed<T> implements Signal<T> {}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
WritableSignal<T> signal<T>(T initialValue) {
  return _SignalImpl(
      flags: ReactiveFlags.mutable,
      currentValue: initialValue,
      pendingValue: initialValue);
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
