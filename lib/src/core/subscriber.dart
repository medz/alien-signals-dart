import 'link.dart';

abstract final class SubscriberFlags {
  static const computed = 1 << 0;
  static const effect = 1 << 1;
  static const tracking = 1 << 2;
  static const notified = 1 << 3;
  static const recursed = 1 << 4;
  static const dirty = 1 << 5;
  static const pendingComputed = 1 << 6;
  static const pendingEffect = 1 << 7;
  static const propagated = dirty | pendingComputed | pendingEffect;
}

abstract mixin class Subscriber {
  abstract int flags;
  Link? deps;
  Link? depsTail;
}
