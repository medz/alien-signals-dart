import 'package:alien_signals/alien_signals.dart';
import 'package:flutter/widgets.dart';

import '../_internal/signals_element.dart';

mixin Signals on StatelessWidget {
  @override
  StatelessElement createElement() {
    return _StatelessSignalsElement(this);
  }
}

class _StatelessSignalsElement extends StatelessElement with SignalsElement {
  _StatelessSignalsElement(super.widget) : scope = effectScope() {
    effect = scope.run(() => Effect(markNeedsBuild));
  }

  @override
  final EffectScope scope;

  @override
  late final Effect effect;
}
