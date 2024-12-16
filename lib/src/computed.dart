import 'effect.dart';
import 'system.dart';
import 'types.dart';

Computed<T> computed<T>(T Function(T? value) getter) => Computed(getter);

class Computed<T> implements IComputed, ISignal {
  Computed(this.getter);

  final T Function(T? _) getter;
  T? cachedValue;

  @override
  Link? deps;

  @override
  Link? depsTail;

  @override
  SubscriberFlags flags = SubscriberFlags.dirty;

  @override
  int? lastTrackedId;

  @override
  Link? subs;

  @override
  Link? subsTail;

  @override
  int version = 0;

  @override
  get() {
    final f = flags;
    if (f & SubscriberFlags.dirty != SubscriberFlags.none) {
      update();
    } else if (f & SubscriberFlags.toCheckDirty != SubscriberFlags.none) {
      if (deps != null && checkDirty(deps!)) {
        update();
      } else {
        flags &= ~SubscriberFlags.toCheckDirty;
      }
    }

    if (activeTrackId != 0 && lastTrackedId != activeTrackId) {
      lastTrackedId = activeTrackId;
      link(this, activeSub!).version = version;
    }

    return cachedValue!;
  }

  @override
  bool update() {
    final prevSub = activeSub, prevTrackId = activeTrackId;
    setActiveSub(this, nextTrackId());
    startTrack(this);

    final oldValue = cachedValue;
    late final T newValue;

    try {
      newValue = getter(oldValue);
    } finally {
      setActiveSub(prevSub, prevTrackId);
      endTrack(this);
    }

    if (!identical(oldValue, newValue)) {
      cachedValue = newValue;
      version++;
      return true;
    }

    return false;
  }
}
