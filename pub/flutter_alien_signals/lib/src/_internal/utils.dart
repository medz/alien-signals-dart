import 'package:alien_signals/alien_signals.dart';

extension EffectScopeUtils on EffectScope {
  void Function() on() {
    final prevScope = activeEffectScope;
    final prevTrackId = activeScopeTrackId;
    setActiveScope(this, trackId);
    return () => setActiveScope(prevScope, prevTrackId);
  }
}

extension EffectUtils on Effect {
  void Function() on([EffectScope? scope]) {
    final reset = scope?.on();
    final prevSub = activeSub;
    final prevTrackId = activeTrackId;
    setActiveSub(this, nextTrackId());
    startTrack(this);
    return () {
      reset?.call();
      setActiveSub(prevSub, prevTrackId);
      endTrack(this);
    };
  }
}
