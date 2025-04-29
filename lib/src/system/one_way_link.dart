class OneWayLink<T> {
  OneWayLink({required this.target, this.linked});

  T target;
  OneWayLink<T>? linked;
}
