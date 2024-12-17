import 'types.dart';

abstract interface class IEffect implements Subscriber, Notifiable {}

abstract interface class IComputed implements Dependency, Subscriber {
  abstract int version;
  bool update();
}

abstract interface class Dependency {
  Link? subs;
  Link? subsTail;
  int? lastTrackedId;
}

extension type const SubscriberFlags._(int value) implements int {
  /// No flags set
  static const none = SubscriberFlags._(0);

  /// Currently tracking dependencies
  static const tracking = SubscriberFlags._(1 << 0);

  /// Can propagate changes to dependents
  static const canPropagate = SubscriberFlags._(1 << 1);

  /// Need to run inner effects
  static const runInnerEffects = SubscriberFlags._(1 << 2);

  /// Need to check if dirty
  static const toCheckDirty = SubscriberFlags._(1 << 3);

  /// Is dirty and needs update
  static const dirty = SubscriberFlags._(1 << 4);

  /// Bitwise NOT operator for flags
  SubscriberFlags operator ~() {
    return SubscriberFlags._(~value);
  }

  /// Bitwise AND operator for flags
  SubscriberFlags operator &(int other) {
    return SubscriberFlags._(value & other);
  }

  /// Bitwise OR operator for flags
  SubscriberFlags operator |(int other) {
    return SubscriberFlags._(value | other);
  }
}

abstract interface class Subscriber {
  abstract SubscriberFlags flags;
  Link? deps;
  Link? depsTail;
}

class Link {
  Link({
    required Dependency this.dep,
    required Subscriber this.sub,
    required this.version,
    this.prevSub,
    this.nextSub,
    this.nextDep,
  });

  Dependency? dep;
  Subscriber? sub;

  int version;

  Link? prevSub;
  Link? nextSub;

  Link? nextDep;
}

int _batchDepth = 0;
Notifiable? _queuedEffects;
Notifiable? _queuedEffectsTail;
Link? _linkPool;

void startBatch() {
  ++_batchDepth;
}

void endBatch() {
  if ((--_batchDepth) == 0) {
    _drainQueuedEffects();
  }
}

void _drainQueuedEffects() {
  while (_queuedEffects != null) {
    final effect = _queuedEffects!;
    final queuedNext = effect.nextNotify;
    if (queuedNext != null) {
      effect.nextNotify = null;
      _queuedEffects = queuedNext;
    } else {
      _queuedEffects = null;
      _queuedEffectsTail = null;
    }
    effect.notify();
  }
}

Link link(Dependency dep, Subscriber sub) {
  final currentDep = sub.depsTail;
  final nextDep = currentDep != null ? currentDep.nextDep : sub.deps;

  if (nextDep != null && nextDep.dep == dep) {
    sub.depsTail = nextDep;
    return nextDep;
  } else {
    return _linkNewDep(dep, sub, nextDep, currentDep);
  }
}

Link _linkNewDep(
  Dependency dep,
  Subscriber sub,
  Link? nextDep,
  Link? depsTail,
) {
  late Link newLink;

  if (_linkPool != null) {
    newLink = _linkPool!;
    _linkPool = newLink.nextDep;
    newLink.nextDep = nextDep;
    newLink.dep = dep;
    newLink.sub = sub;
  } else {
    newLink = Link(
      dep: dep,
      sub: sub,
      version: 0,
      nextDep: nextDep,
    );
  }

  if (depsTail == null) {
    sub.deps = newLink;
  } else {
    depsTail.nextDep = newLink;
  }

  if (dep.subs == null) {
    dep.subs = newLink;
  } else {
    final oldTail = dep.subsTail!;
    newLink.prevSub = oldTail;
    oldTail.nextSub = newLink;
  }

  sub.depsTail = newLink;
  dep.subsTail = newLink;

  return newLink;
}

void propagate(Link? link,
    [SubscriberFlags targetFlag = SubscriberFlags.dirty]) {
  do {
    final sub = link!.sub!;
    final subFlags = sub.flags;

    if ((subFlags & SubscriberFlags.tracking) == 0) {
      bool canPropagate = (subFlags >> 2) == 0;
      if (!canPropagate && (subFlags & SubscriberFlags.canPropagate) != 0) {
        sub.flags &= ~SubscriberFlags.canPropagate;
        canPropagate = true;
      }
      if (canPropagate) {
        sub.flags |= targetFlag;
        final subSubs = switch (sub) {
          Dependency(:final subs) => subs,
          _ => null,
        };
        if (subSubs != null) {
          propagate(
              subSubs,
              sub is Notifiable
                  ? SubscriberFlags.runInnerEffects
                  : SubscriberFlags.toCheckDirty);
        } else if (sub is Notifiable) {
          if (_queuedEffectsTail != null) {
            _queuedEffectsTail!.nextNotify = sub as Notifiable;
          } else {
            _queuedEffects = sub as Notifiable;
          }
          _queuedEffectsTail = sub as Notifiable;
        }
      } else if ((sub.flags & targetFlag) == 0) {
        sub.flags |= targetFlag;
      }
    } else if (_isValidLink(link, sub)) {
      if ((subFlags >> 2) == 0) {
        sub.flags |= targetFlag | SubscriberFlags.canPropagate;
        final subSubs = switch (sub) {
          Dependency(:final subs) => subs,
          _ => null,
        };
        if (subSubs != null) {
          propagate(
            subSubs,
            sub is Notifiable
                ? SubscriberFlags.runInnerEffects
                : SubscriberFlags.toCheckDirty,
          );
        }
      } else if ((sub.flags & targetFlag) == 0) {
        sub.flags |= targetFlag;
      }
    }

    link = link.nextSub;
  } while (link != null);

  if (targetFlag == SubscriberFlags.dirty && _batchDepth == 0) {
    _drainQueuedEffects();
  }
}

bool _isValidLink(Link subLink, Subscriber sub) {
  final depsTail = sub.depsTail;
  if (depsTail != null) {
    Link? link = sub.deps!;
    do {
      if (link == subLink) {
        return true;
      }
      if (link == depsTail) {
        break;
      }
      link = link?.nextDep;
    } while (link != null);
  }
  return false;
}

bool checkDirty(Link? link) {
  do {
    final dep = link!.dep!;
    if (dep is IComputed) {
      if (dep.version != link.version) {
        return true;
      }
      final depFlags = dep.flags;
      if ((depFlags & SubscriberFlags.dirty) != 0) {
        if (dep.update()) {
          return true;
        }
      } else if ((depFlags & SubscriberFlags.toCheckDirty) != 0) {
        if (checkDirty(dep.deps!)) {
          if (dep.update()) {
            return true;
          }
        } else {
          dep.flags &= ~SubscriberFlags.toCheckDirty;
        }
      }
    }
    link = link.nextDep;
  } while (link != null);

  return false;
}

void startTrack(Subscriber sub) {
  sub.depsTail = null;
  sub.flags = SubscriberFlags.tracking;
}

void endTrack(Subscriber sub) {
  final depsTail = sub.depsTail;
  if (depsTail != null) {
    if (depsTail.nextDep != null) {
      _clearTrack(depsTail.nextDep);
      depsTail.nextDep = null;
    }
  } else if (sub.deps != null) {
    _clearTrack(sub.deps);
    sub.deps = null;
  }
  sub.flags &= ~SubscriberFlags.tracking;
}

void _clearTrack(Link? link) {
  do {
    final dep = link!.dep!;
    final nextDep = link.nextDep;
    final nextSub = link.nextSub;
    final prevSub = link.prevSub;

    if (nextSub != null) {
      nextSub.prevSub = prevSub;
      link.nextSub = null;
    } else {
      dep.subsTail = prevSub;
      dep.lastTrackedId = 0;
    }

    if (prevSub != null) {
      prevSub.nextSub = nextSub;
      link.prevSub = null;
    } else {
      dep.subs = nextSub;
    }

    link.dep = null;
    link.sub = null;
    link.nextDep = _linkPool;
    _linkPool = link;

    if (dep.subs == null && dep is Subscriber) {
      if (dep is Notifiable) {
        (dep as Subscriber).flags = SubscriberFlags.none;
      } else {
        (dep as Subscriber).flags |= SubscriberFlags.dirty;
      }
      final depDeps = (dep as Subscriber).deps;
      if (depDeps != null) {
        link = depDeps;
        (dep as Subscriber).depsTail!.nextDep = nextDep;
        (dep as Subscriber).deps = null;
        (dep as Subscriber).depsTail = null;
        continue;
      }
    }
    link = nextDep;
  } while (link != null);
}
