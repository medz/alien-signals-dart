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
  Effect._(this.fn);

  factory Effect(T Function() fn) {
    final effect = Effect._(fn);
    if (activeTrackId != 0) {
      link(effect, activeSub!);
    } else if (activeScopeTrackId != 0) {
      link(effect, activeEffectScope!);
    }

    return effect;
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
    final flags = this.flags;
    if ((flags & SubscriberFlags.dirty) != 0) {
      this.run();
      return;
    }
    if ((flags & SubscriberFlags.toCheckDirty) != 0) {
      if (checkDirty(this.deps!)) {
        this.run();
        return;
      } else {
        this.flags &= ~SubscriberFlags.toCheckDirty;
      }
    }
    if ((flags & SubscriberFlags.runInnerEffects) != 0) {
      this.flags &= ~SubscriberFlags.runInnerEffects;
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
      return this.fn();
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
