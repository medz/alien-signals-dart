import 'effect.dart';
import 'system.dart';
import 'types.dart';

class Signal<T> implements Dependency, IWritableSignal<T> {
  Signal(this.currentValue);

  T currentValue;

  @override
  int? lastTrackedId = 0;

  @override
  Link? subs;

  @override
  Link? subsTail;

  @override
  T get() {
    if (activeTrackId != 0 && activeTrackId != lastTrackedId) {
      lastTrackedId = activeTrackId;
      link(this, activeSub!);
    }

    return currentValue;
  }

  @override
  set(T value) {
    if (currentValue != (currentValue = value)) {
      final subs = this.subs;
      if (subs != null) {
        propagate(subs);
      }
    }
  }
}

Signal<T> signal<T>(T value) => Signal(value);
