import 'effect.dart';
import 'effect_scope.dart';
import 'system.dart';
import 'types.dart';

Computed<T> computed<T>(T Function(T? oldValue) getter) {
  return Computed<T>(getter);
}

class Computed<T> implements IComputed, ISignal<T> {
  Computed(this.getter);

  final T Function(T? oldValue) getter;
  T? cachedValue;

  @override
  Link? deps;

  @override
  Link? depsTail;

  @override
  SubscriberFlags flags = SubscriberFlags.dirty;

  @override
  int? lastTrackedId = 0;

  @override
  Link? subs;

  @override
  Link? subsTail;

  @override
  int version = 0;

  @override
  T get() {
    if ((flags & SubscriberFlags.dirty) != 0) {
      update();
    } else if ((flags & SubscriberFlags.toCheckDirty) != 0) {
      if (checkDirty(deps)) {
        update();
      } else {
        flags &= ~SubscriberFlags.toCheckDirty;
      }
    }
    if (activeTrackId != 0) {
      if (lastTrackedId != activeTrackId) {
        lastTrackedId = activeTrackId;
        link(this, activeSub!).version = version;
      }
    } else if (activeScopeTrackId != 0) {
      if (lastTrackedId != activeScopeTrackId) {
        lastTrackedId = activeScopeTrackId;
        link(this, activeEffectScope!).version = this.version;
      }
    }
    return cachedValue!;
  }

  @override
  bool update() {
    final prevSub = activeSub;
    final prevTrackId = activeTrackId;
    setActiveSub(this, nextTrackId());
    startTrack(this);
    final oldValue = cachedValue;
    late T newValue;
    try {
      newValue = getter(oldValue);
    } finally {
      setActiveSub(prevSub, prevTrackId);
      endTrack(this);
    }
    if (oldValue != newValue) {
      cachedValue = newValue;
      version++;
      return true;
    }
    return false;
  }
}
