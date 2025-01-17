import 'upstream.dart';

extension ValueSignal<T> on Signal<T> {
  T get value => this();
}

extension ValueWritableSignal<T> on WriteableSignal<T> {
  T get value => this();
  set value(T value) => this(value);
}
