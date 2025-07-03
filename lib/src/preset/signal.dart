import 'package:alien_signals/alien_signals.dart';

import '_system.dart';
import 'types.dart' as types;

class Signal<T> with Dependency implements types.WriteableSignal<T> {
  Signal(this.untracked);

  @override
  T untracked;

  @override
  T call([T? value, bool setNulls = false]) {
    if (value != null || (null is T && setNulls == true)) {
      if (untracked != (untracked = value as T)) {
        final subs = this.subs;
        if (subs != null) {
          system.propagate(subs);
          if (system.batchDepth == 0) {
            system.processEffectNotifications();
          }
        }
      }
    } else if (system.activeSub != null) {
      system.link(this, system.activeSub!);
    }

    return untracked;
  }
}

types.WriteableSignal<T> signal<T>(T value) {
  return Signal(value);
}
