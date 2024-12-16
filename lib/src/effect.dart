import 'effect_scope.dart';
import 'system.dart';

Subscriber? activeSub;
int activeTrackId = 0, lastTrackId = 0;

void setActiveSub(Subscriber? sub, int trackId) {
  activeSub = sub;
  activeTrackId = trackId;
}

int nextTrackId() => ++lastTrackId;

Effect effect<T>(T Function() fn) {
  final e = Effect(fn);
  e.run();

  return e;
}

class Effect<T> implements IEffect, Dependency {
  Effect(this.fn) {
    if (activeTrackId != 0) {
      link(this, activeSub!);
    } else if (activeEffectScope != null) {
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
  IEffect? nextNotify;

  @override
  Link? subs;

  @override
  Link? subsTail;

  @override
  void notify() {
    final f = flags;
    if (f & SubscriberFlags.dirty != SubscriberFlags.none) {
      run();
      return;
    }

    if (f & SubscriberFlags.toCheckDirty != SubscriberFlags.none) {
      if (deps != null && checkDirty(deps!)) {
        run();
        return;
      } else {
        flags &= ~SubscriberFlags.toCheckDirty;
      }
    }

    if (f & SubscriberFlags.runInnerEffects != SubscriberFlags.none) {
      flags &= ~SubscriberFlags.runInnerEffects;
      for (var link = deps; link != null; link = link.nextDep) {
        final effect = switch (link.dep) {
          IEffect effect => effect,
          _ => null,
        };
        effect?.notify();
      }
    }
  }

  T run() {
    final prevSub = activeSub, prevTrackId = activeTrackId;

    setActiveSub(this, nextTrackId());
    startTrack(this);

    try {
      return fn();
    } finally {
      setActiveSub(prevSub, prevTrackId);
      endTrack(this);
    }
  }
}
