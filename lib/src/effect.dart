import 'package:alien_signals/src/types.dart';

import 'effect_scope.dart';
import 'system.dart';

Subscriber? activeSub;
int activeTrackId = 0;
int lastTrackId = 0;

void setActiveSub(Subscriber? sub, int trackId) {
  activeSub = sub;
  activeTrackId = trackId;
}

int nextTrackId() {
  return ++lastTrackId;
}

Effect<T> effect<T>(T Function() fn) {
  return Effect(fn)..run();
}

class Effect<T> implements IEffect, Dependency {
  Effect(this.fn) {
    if (activeTrackId != 0) {
      link(this, activeSub!);
    } else if (activeScopeTrackId != 0) {
      link(this, activeEffectScope!);
    }
  }

  final T Function() fn;

  @override
  Link? deps;

  @override
  Link? depsTail;

  @override
  SubscriberFlags flags = SubscriberFlags.dirty;

  @override
  int? lastTrackedId;

  @override
  Notifiable? nextNotify;

  @override
  Link? subs;

  @override
  Link? subsTail;

  @override
  void notify() {
    if ((flags & SubscriberFlags.dirty) != 0) {
      run();
      return;
    }
    if ((flags & SubscriberFlags.toCheckDirty) != 0) {
      if (checkDirty(this.deps!)) {
        run();
        return;
      } else {
        flags &= ~SubscriberFlags.toCheckDirty;
      }
    }
    if ((flags & SubscriberFlags.runInnerEffects) != 0) {
      flags &= ~SubscriberFlags.runInnerEffects;
      Link? link = this.deps;
      do {
        final dep = link!.dep;
        if (dep is Notifiable) {
          (dep as Notifiable).notify();
        }

        link = link.nextDep;
      } while (link != null);
    }
  }

  T run() {
    final prevSub = activeSub;
    final prevTrackId = activeTrackId;
    setActiveSub(this, nextTrackId());
    startTrack(this);
    try {
      return fn();
    } finally {
      setActiveSub(prevSub, prevTrackId);
      endTrack(this);
    }
  }

  void stop() {
    startTrack(this);
    endTrack(this);
  }
}
