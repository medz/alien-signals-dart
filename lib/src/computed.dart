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

  T? currentValue;

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
  T get() {
    if ((flags & SubscriberFlags.dirty) != 0) {
      if (update() && subs != null) {
        shallowPropagate(subs);
      }
    } else if ((flags & SubscriberFlags.toCheckDirty) != 0) {
      if (checkDirty(deps)) {
        if (update() && subs != null) {
          shallowPropagate(subs);
        }
      } else {
        flags &= ~SubscriberFlags.toCheckDirty;
      }
    }

    if (activeTrackId != 0) {
      if (lastTrackedId != activeTrackId) {
        lastTrackedId = activeTrackId;
        link(this, activeSub!);
      }
    } else if (activeScopeTrackId != 0) {
      if (lastTrackedId != activeScopeTrackId) {
        lastTrackedId = activeScopeTrackId;
        link(this, activeEffectScope!);
      }
    }

    return currentValue!;
  }

  @override
  bool update() {
    final prevSub = activeSub;
    final prevTrackId = activeTrackId;
    setActiveSub(this, nextTrackId());
    startTrack(this);

    final oldValue = currentValue;
    try {
      return (currentValue = getter(oldValue)) != oldValue;
    } finally {
      setActiveSub(prevSub, prevTrackId);
      endTrack(this);
    }
  }
}
