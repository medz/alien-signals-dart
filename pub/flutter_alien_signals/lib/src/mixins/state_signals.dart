import 'package:alien_signals/preset.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../_internal/signals_element.dart';
import '../_internal/utils.dart';

mixin StateSignals on StatefulWidget {
  @override
  StatefulElement createElement() {
    final stop = effectScope(loop);
    final reset = stop.sub.on();
    try {
      return _SignalsElement(this, stop);
    } finally {
      reset();
    }
  }
}

class _SignalsElement extends StatefulElement with SignalsElement {
  _SignalsElement(super.widget, this.scopeStop) {
    system.runEffectScope(scopeStop.sub, () {
      effectStop = effect(markNeedsBuild);
    });
  }

  @override
  final EffectStop<EffectScope> scopeStop;

  @override
  late final EffectStop<Effect> effectStop;

  @override
  void mount(Element? parent, Object? newSlot) {
    final reset = scopeStop.sub.on();
    try {
      super.mount(parent, newSlot);
    } finally {
      reset();
    }
  }
}
