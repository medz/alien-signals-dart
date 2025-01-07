import 'upstream.dart';

extension ValueSignal<T> on ISignal<T> {
  T get value => get();
}

extension ValueWritableSignal<T> on IWritableSignal<T> {
  T get value => get();
  set value(T value) => set(value);
}
