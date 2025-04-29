extension type const Flags._(int raw) implements int {
  static const none = Flags._(0);
  static const mutable = Flags._(1 << 0);
  static const watching = Flags._(1 << 1);
  static const running = Flags._(1 << 2);
  static const recursed = Flags._(1 << 3);
  static const dirty = Flags._(1 << 4);
  static const pending = Flags._(1 << 5);

  Flags operator |(int other) => Flags._(raw | other);
  Flags operator &(int other) => Flags._(raw & other);
}
