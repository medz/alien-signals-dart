import 'package:alien_signals/preset.dart';
import 'package:flutter/widgets.dart';

import '../_internal/signals_element.dart';
import '../_internal/utils.dart';

mixin Signals on StatelessWidget {
  @override
  StatelessElement createElement() {
    return _StatelessSignalsElement(this);
  }
}

class _StatelessSignalsElement extends StatelessElement with SignalsElement {
  _StatelessSignalsElement(super.widget) : scopeStop = effectScope(loop) {
    system.runEffectScope(scopeStop.sub, () {
      effectStop = effect(markNeedsBuild);
    });
  }

  @override
  final EffectStop<EffectScope> scopeStop;

  @override
  late final EffectStop<Effect> effectStop;
}
