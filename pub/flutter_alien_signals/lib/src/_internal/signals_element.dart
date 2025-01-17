import 'package:alien_signals/alien_signals.dart';
import 'package:alien_signals/preset.dart';
import 'package:flutter/widgets.dart';

import 'utils.dart';

SignalsElement? currentElement;

mixin SignalsElement on ComponentElement {
  EffectStop<EffectScope> get scopeStop;
  EffectStop<Effect> get effectStop;

  final signals = <Signal>[];
  final subs = <Subscriber>[];
  int signalCounter = 0;
  int subCounter = 0;

  @override
  Widget build() {
    final prevElement = currentElement;
    final reset = effectStop.sub.on(scopeStop.sub);
    currentElement = this;
    signalCounter = subCounter = 0;
    try {
      return super.build();
    } finally {
      final stopSubs = subs.skip(subCounter);

      reset();
      currentElement = prevElement;
      signals.length = signalCounter;
      subs.length = subCounter;

      if (stopSubs.isEmpty) {
        for (final sub in stopSubs) {
          system.startTracking(sub);
          system.endTracking(sub);
        }
      }
    }
  }

  @override
  void unmount() {
    signals.clear();
    subs.clear();
    scopeStop();
    super.unmount();
  }
}
