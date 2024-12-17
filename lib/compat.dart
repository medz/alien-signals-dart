import 'src/types.dart';

extension ValueGetterSignal<T> on ISignal<T> {
  T get value => get();
}

extension ValuePropSignal<T> on IWritableSignal<T> {
  T get value => get();
  set value(T value) => set(value);
}
