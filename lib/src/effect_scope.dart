import 'effect.dart';
import 'system.dart';

EffectScope? activeEffectScope;
int activeScopeTrackId = 0;

void setActiveScope(EffectScope? scope, int trackId) {
  activeEffectScope = scope;
  activeScopeTrackId = trackId;
}

T untrackScope<T>(T Function() fn) {
  final prevSub = activeEffectScope;
  final prevTrackId = activeScopeTrackId;
  setActiveScope(null, 0);
  try {
    return fn();
  } finally {
    setActiveScope(prevSub, prevTrackId);
  }
}

EffectScope effectScope() {
  return EffectScope();
}

class EffectScope implements IEffect {
  @override
  Link? deps;

  @override
  Link? depsTail;

  @override
  SubscriberFlags flags = SubscriberFlags.none;

  @override
  IEffect? nextNotify;

  int trackId = nextTrackId();

  @override
  void notify() {
    if ((flags & SubscriberFlags.innerEffectsPending) != 0) {
      flags &= ~SubscriberFlags.innerEffectsPending;
      Link? link = deps;
      do {
        final dep = link?.dep;
        if (dep is IEffect) {
          (dep as IEffect).notify();
        }

        link = link?.nextDep;
      } while (link != null);
    }
  }

  T run<T>(T Function() fn) {
    final prevSub = activeEffectScope;
    final prevTrackId = activeScopeTrackId;
    activeEffectScope = this;
    activeScopeTrackId = trackId;
    try {
      return fn();
    } finally {
      activeEffectScope = prevSub;
      activeScopeTrackId = prevTrackId;
    }
  }

  void stop() {
    startTrack(this);
    endTrack(this);
  }
}
