abstract interface class ISignal<T> {
  T get();
}

abstract interface class IWritableSignal<T> implements ISignal<T> {
  set(T value);
}
