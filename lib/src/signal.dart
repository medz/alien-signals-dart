import 'effect.dart';
import 'system.dart';
import 'types.dart';

Signal<T> signal<T>(T value) {
  return Signal(value);
}

class Signal<T> implements Dependency<T>, IWritableSignal<T> {
  Signal(this.currentValue);

  @override
  T currentValue;

  @override
  int? lastTrackedId = 0;

  @override
  Link? subs;

  @override
  Link? subsTail;

  @override
  T get() {
    if (activeTrackId != 0 && this.lastTrackedId != activeTrackId) {
      this.lastTrackedId = activeTrackId;
      link(this, activeSub!);
    }

    return this.currentValue;
  }

  @override
  set(T value) {
    if (this.currentValue != (this.currentValue = value)) {
      final subs = this.subs;
      if (subs != null) {
        propagate(subs);
      }
    }
  }
}
