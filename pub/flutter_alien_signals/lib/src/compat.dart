import 'upstream.dart';

extension ValueSignal<T> on Signal<T> {
  T get value => this();
}

extension ValueWritableSignal<T> on WritableSignal<T> {
  T get value => this();
  set value(T value) => this(value);
}
