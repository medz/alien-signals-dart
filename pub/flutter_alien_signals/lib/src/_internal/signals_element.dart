import 'package:alien_signals/alien_signals.dart';
import 'package:flutter/widgets.dart';

import 'utils.dart';

SignalsElement? currentElement;

mixin SignalsElement on ComponentElement {
  EffectScope get scope;
  Effect get effect;

  final signals = <Signal>[];
  final subs = <Subscriber>[];
  int signalCounter = 0;
  int subCounter = 0;

  @override
  Widget build() {
    final prevElement = currentElement;
    final reset = effect.on(scope);
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
          startTrack(sub);
          endTrack(sub);
        }
      }
    }
  }

  @override
  void unmount() {
    signals.clear();
    subs.clear();
    scope.stop();
    super.unmount();
  }
}
