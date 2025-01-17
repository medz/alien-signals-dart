import 'package:alien_signals/preset.dart';

void loop() {}

extension EffectScopeUtils on EffectScope {
  void Function() on() {
    final prevScope = system.activeScope;
    system.activeScope = this;
    return () {
      system.activeScope = prevScope;
    };
  }
}

extension EffectUtils on Effect {
  void Function() on([EffectScope? scope]) {
    final reset = scope?.on();
    final prevSub = system.activeSub;

    system.activeSub = this;
    system.startTracking(this);
    return () {
      reset?.call();
      system.activeSub = prevSub;
      system.endTracking(this);
    };
  }
}
