import 'package:alien_signals/alien_signals.dart';

extension EffectScopeUtils on EffectScope {
  void Function() on() {
    final prevScope = activeEffectScope;
    setActiveScope(this);
    return () => setActiveScope(prevScope);
  }
}

extension EffectUtils on Effect {
  void Function() on([EffectScope? scope]) {
    final reset = scope?.on();
    final prevSub = activeSub;
    setActiveSub(this);
    startTrack(this);
    return () {
      reset?.call();
      setActiveSub(prevSub);
      endTrack(this);
    };
  }
}
