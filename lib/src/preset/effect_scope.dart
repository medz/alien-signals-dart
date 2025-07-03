import 'package:alien_signals/alien_signals.dart';

import '_system.dart';
import 'types.dart' as types;

class EffectScope with Subscriber implements types.EffectScope {
  @override
  int flags = SubscriberFlags.effect;

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void call() {
    system.startTracking(this);
    system.endTracking(this);
  }
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
types.EffectScope effectScope(void Function() run) {
  final scope = EffectScope(), prevScope = system.activeScope;
  try {
    system.activeScope = scope;
    system.startTracking(scope);
    run();
    return scope;
  } finally {
    system.activeScope = prevScope;
    system.endTracking(scope);
  }
}
