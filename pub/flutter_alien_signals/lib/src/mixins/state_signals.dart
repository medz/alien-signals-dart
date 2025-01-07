import 'package:alien_signals/alien_signals.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../_internal/signals_element.dart';
import '../_internal/utils.dart';

mixin StateSignals on StatefulWidget {
  @override
  StatefulElement createElement() {
    final scope = effectScope();
    final reset = scope.on();
    try {
      return _SignalsElement(this, scope);
    } finally {
      reset();
    }
  }
}

class _SignalsElement extends StatefulElement with SignalsElement {
  _SignalsElement(super.widget, this.scope) {
    effect = scope.run(() => Effect(markNeedsBuild));
  }

  @override
  final EffectScope scope;

  @override
  late final Effect effect;

  @override
  void mount(Element? parent, Object? newSlot) {
    final reset = scope.on();
    try {
      super.mount(parent, newSlot);
    } finally {
      reset();
    }
  }
}
