import 'package:alien_signals/alien_signals.dart';

class RecursiveComputed<T> extends Computed<T> {
  RecursiveComputed(super.getter);

  @override
  T get() {
    final flags = this.flags;
    if (flags & (SubscriberFlags.toCheckDirty | SubscriberFlags.dirty) != 0 &&
        isDirty(this, flags) &&
        update() &&
        subs != null) {
      shallowPropagate(subs);
    }

    if ((flags & SubscriberFlags.recursed) != 0) {
      this.flags = flags & ~SubscriberFlags.recursed;
      return get();
    }

    return super.get();
  }
}
