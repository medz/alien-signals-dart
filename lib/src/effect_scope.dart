import 'system.dart';

EffectScope? activeEffectScope;

EffectScope effectScope() => EffectScope();

class EffectScope implements Subscriber {
  @override
  Link? deps;

  @override
  Link? depsTail;

  @override
  SubscriberFlags flags = SubscriberFlags.none;

  void notify() {
    if (flags & SubscriberFlags.runInnerEffects != SubscriberFlags.none) {
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

  T run<T>(T Function() fn) {
    final prevSub = activeEffectScope;
    activeEffectScope = this;
    try {
      return fn();
    } finally {
      activeEffectScope = prevSub;
    }
  }

  void stop() {
    startTrack(this);
    endTrack(this);
  }
}
