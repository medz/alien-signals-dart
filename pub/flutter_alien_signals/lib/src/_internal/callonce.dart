R callonce<T, R extends T>({
  required R Function() factory,
  required int index,
  required List<T> container,
}) {
  if (container.isEmpty || container.length - 1 < index) {
    final result = factory();
    container.add(result);

    return result;
  }

  final cached = container.elementAtOrNull(index);
  if (cached is R) {
    return cached;
  }

  return container[index] = factory();
}
