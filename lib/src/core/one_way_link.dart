class OneWayLink<T> {
  OneWayLink(this.target, [this.linked]);

  final T target;
  OneWayLink<T>? linked;
}
