import 'package:alien_signals/alien_signals.dart';

import 'preset_system.dart';

extension type const EffectStop<T extends Subscriber>(T sub) {
  void call() {
    system.startTracking(sub);
    system.endTracking(sub);
  }
}
