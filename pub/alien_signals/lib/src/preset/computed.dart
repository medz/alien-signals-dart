import 'package:alien_signals/alien_signals.dart';

import '_system.dart';
import 'types.dart' as types;

class Computed<T> with Dependency, Subscriber implements types.Computed<T> {
  Computed(this.getter);

  @override
  final T Function(T? prevValue) getter;

  @override
  int flags = SubscriberFlags.computed | SubscriberFlags.dirty;

  @override
  T? untracked;

  @override
  T call() {
    if ((flags & (SubscriberFlags.dirty | SubscriberFlags.pendingComputed)) !=
        0) {
      system.processComputedUpdate(this, flags);
    }

    if (system.activeSub != null) {
      system.link(this, system.activeSub!);
    } else if (system.activeScope != null) {
      system.link(this, system.activeScope!);
    }

    return untracked as T;
  }
}

types.Computed<T> computed<T>(T Function(T? prevValue) getter) {
  return Computed<T>(getter);
}
