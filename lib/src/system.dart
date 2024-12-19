import 'types.dart';

/// Interface for reactive effects that can subscribe to dependencies and be notified of changes
abstract interface class IEffect implements Subscriber, Notifiable {}

/// Interface for computed values that can track dependencies and maintain version state
abstract interface class IComputed implements Dependency, Subscriber {
  /// Current version number of the computed value
  abstract int version;

  /// Update the computed value if needed
  /// Returns true if value changed
  bool update();
}

/// Interface for values that can be depended on by subscribers
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

/// Interface for subscribers that can track dependencies
abstract interface class Subscriber {
  abstract SubscriberFlags flags;
  Link? deps;
  Link? depsTail;
}

/// Link class representing dependency relationships
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

/// Start a new batch of updates
void startBatch() {
  ++_batchDepth;
}

/// End the current batch of updates
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

/// Create or reuse a link between a dependency and subscriber
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

/// Propagate changes through the dependency graph
void propagate(Link? subs) {
  SubscriberFlags targetFlag = SubscriberFlags.dirty;
  Link? link = subs;
  int stack = 0;
  Link? nextSub;

  top:
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
        final subSubs = (sub as Dependency).subs;
        if (subSubs != null) {
          if (subSubs.nextSub != null) {
            subSubs.prevSub = subs;
            link = subs = subSubs;
            targetFlag = SubscriberFlags.toCheckDirty;
            ++stack;
          } else {
            link = subSubs;
            targetFlag = sub is Notifiable
                ? SubscriberFlags.runInnerEffects
                : SubscriberFlags.toCheckDirty;
          }
          continue;
        }
        if (sub is Notifiable) {
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
        final subSubs = (sub as Dependency).subs;
        if (subSubs != null) {
          if (subSubs.nextSub != null) {
            subSubs.prevSub = subs;
            link = subs = subSubs;
            targetFlag = SubscriberFlags.toCheckDirty;
            ++stack;
          } else {
            link = subSubs;
            targetFlag = sub is Notifiable
                ? SubscriberFlags.runInnerEffects
                : SubscriberFlags.toCheckDirty;
          }
          continue;
        }
      } else if ((sub.flags & targetFlag) == 0) {
        sub.flags |= targetFlag;
      }
    }

    if ((nextSub = subs!.nextSub) == null) {
      if (stack > 0) {
        Dependency dep = subs.dep!;
        do {
          --stack;
          final depSubs = dep.subs!;
          final prevLink = depSubs.prevSub!;
          depSubs.prevSub = null;
          link = subs = prevLink.nextSub;
          if (subs != null) {
            targetFlag = stack > 0
                ? SubscriberFlags.toCheckDirty
                : SubscriberFlags.dirty;
            continue top;
          }
          dep = prevLink.dep!;
        } while (stack > 0);
      }
      break;
    }
    if (link != subs) {
      targetFlag =
          stack > 0 ? SubscriberFlags.toCheckDirty : SubscriberFlags.dirty;
    }
    link = subs = nextSub;
  } while (true);

  if (_batchDepth == 0) {
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

/// Check if any dependencies are dirty and need updates
bool checkDirty(Link? deps) {
  int stack = 0;
  late bool dirty;
  Link? nextDep;

  top:
  do {
    dirty = false;
    final dep = deps!.dep;
    if (dep is IComputed) {
      if (dep.version != deps.version) {
        dirty = true;
      } else {
        final depFlags = dep.flags;
        if ((depFlags & SubscriberFlags.dirty) != 0) {
          dirty = dep.update();
        } else if ((depFlags & SubscriberFlags.toCheckDirty) != 0) {
          final depSubs = dep.subs!;
          if (depSubs.nextSub != null) {
            depSubs.prevSub = deps;
          }
          deps = dep.deps;
          ++stack;
          continue;
        }
      }
    }
    if (dirty || (nextDep = deps.nextDep) == null) {
      if (stack > 0) {
        dynamic sub = deps.sub;
        do {
          --stack;
          final subSubs = sub.subs!;
          Link? prevLink = subSubs.prevSub;
          if (prevLink != null) {
            subSubs.prevSub = null;
          } else {
            prevLink = subSubs;
          }
          if (dirty) {
            if (sub.update()) {
              sub = prevLink!.sub;
              dirty = true;
              continue;
            }
          } else {
            sub.flags &= ~SubscriberFlags.toCheckDirty;
          }

          deps = prevLink!.nextDep;
          if (deps != null) {
            continue top;
          }

          sub = prevLink.sub;
          dirty = false;
        } while (stack > 0);
      }
      return dirty;
    }

    deps = nextDep;
  } while (true);
}

/// Start tracking dependencies for a subscriber
void startTrack(Subscriber sub) {
  sub.depsTail = null;
  sub.flags = SubscriberFlags.tracking;
}

/// End tracking dependencies for a subscriber
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
