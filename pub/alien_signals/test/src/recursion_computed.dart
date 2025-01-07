import 'package:alien_signals/alien_signals.dart';

class RecursiveComputed<T> extends Computed<T> {
  RecursiveComputed(super.getter);

  @override
  T get() {
    if ((flags & SubscriberFlags.dirty) != 0) {
      if (update() && subs != null) {
        shallowPropagate(subs);
      }
    } else if ((flags & SubscriberFlags.toCheckDirty) != 0) {
      if (checkDirty(deps)) {
        if (update() && subs != null) {
          shallowPropagate(subs);
        }
      } else {
        flags &= ~SubscriberFlags.toCheckDirty;
      }
    }

    if ((flags & SubscriberFlags.recursed) != 0) {
      flags &= ~SubscriberFlags.recursed;
      return get();
    }

    return super.get();
  }
}
