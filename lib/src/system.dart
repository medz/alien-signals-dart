abstract interface class IEffect implements Subscriber {
  void notify();
  IEffect? nextNotify;
}

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
  static const none = SubscriberFlags._(0);
  static const tracking = SubscriberFlags._(1 << 0);
  static const canPropagate = SubscriberFlags._(1 << 1);
  static const runInnerEffects = SubscriberFlags._(1 << 2);
  static const toCheckDirty = SubscriberFlags._(1 << 3);
  static const dirty = SubscriberFlags._(1 << 4);

  SubscriberFlags operator ~() {
    return SubscriberFlags._(~value);
  }

  SubscriberFlags operator &(int other) {
    return SubscriberFlags._(value & other);
  }

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
    required this.dep,
    required this.sub,
    required this.version,
    this.prevSub,
    this.nextSub,
    this.nextDep,
  });

  Dependency dep;
  Subscriber sub;
  int version;
  Link? prevSub;
  Link? nextSub;
  Link? nextDep;
}

int _batchDepth = 0;
IEffect? _queuedEffects;
IEffect? _queuedEffectsTail;
Link? _linkPool;

void startBatch() {
  ++_batchDepth;
}

void endBatch() {
  if (--_batchDepth == 0) {
    _drainQueuedEffects();
  }
}

void _drainQueuedEffects() {
  while (_queuedEffects != null) {
    final effect = _queuedEffects!, queuedNext = effect.nextNotify;
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
  final currentDep = sub.depsTail, nextDep = currentDep?.nextDep ?? sub.deps;
  if (nextDep != null && nextDep.dep == dep) {
    sub.depsTail = nextDep;
    return nextDep;
  }

  return _linkNewDep(dep, sub, nextDep, currentDep);
}

Link _linkNewDep(
    Dependency dep, Subscriber sub, Link? nextDep, Link? depsTail) {
  late final Link newLink;
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

void propagate(Link subs) {
  SubscriberFlags targetFlag = SubscriberFlags.dirty;
  Link link = subs;
  int stack = 0;
  Link? nextSub;

  do {
    final sub = link.sub;
    final subFlags = sub.flags;

    if (subFlags & SubscriberFlags.tracking == SubscriberFlags.none) {
      bool canPropagate = subFlags >> 2 == SubscriberFlags.none;
      if (!canPropagate &&
          subFlags & SubscriberFlags.canPropagate != SubscriberFlags.none) {
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
          if (subSubs.nextSub != null) {
            subSubs.prevSub = subs;
            link = subs = subSubs;
            targetFlag = SubscriberFlags.toCheckDirty;
            ++stack;
          } else {
            link = subSubs;
            targetFlag = sub is IEffect
                ? SubscriberFlags.runInnerEffects
                : SubscriberFlags.toCheckDirty;
          }
          continue;
        }

        if (sub is IEffect) {
          if (_queuedEffectsTail != null) {
            _queuedEffectsTail!.nextNotify = sub;
          } else {
            _queuedEffects = sub;
          }

          _queuedEffectsTail = sub;
        }
      } else if (sub.flags & targetFlag == SubscriberFlags.none) {
        sub.flags |= targetFlag;
      }
    } else if (_isValidLink(link, sub)) {
      if (subFlags >> 2 == SubscriberFlags.none) {
        sub.flags |= targetFlag | SubscriberFlags.canPropagate;
        final subSubs = switch (sub) {
          Dependency(:final subs) => subs,
          _ => null,
        };
        if (subSubs != null) {
          if (subSubs.nextSub != null) {
            subSubs.prevSub = subs;
            link = subs = subSubs;
            targetFlag = SubscriberFlags.toCheckDirty;
            ++stack;
          } else {
            link = subSubs;
            targetFlag = sub is IEffect
                ? SubscriberFlags.runInnerEffects
                : SubscriberFlags.toCheckDirty;
          }

          continue;
        }
      } else if (sub.flags & targetFlag == SubscriberFlags.none) {
        sub.flags |= targetFlag;
      }
    }

    nextSub = subs.nextSub;
    if (nextSub == null) {
      if (stack > 0) {
        Dependency dep = subs.dep;
        bool shouldContinue = false;

        do {
          --stack;
          final depSubs = dep.subs!,
              prevLink = depSubs.prevSub!,
              nextSub = prevLink.nextSub;
          depSubs.prevSub = null;

          if (nextSub != null) {
            shouldContinue = true;
            targetFlag = stack > 0
                ? SubscriberFlags.toCheckDirty
                : SubscriberFlags.dirty;
            link = subs = nextSub;
            break;
          }

          dep = prevLink.dep;
        } while (stack > 0);
        if (shouldContinue) continue;
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
    Link? link = sub.deps;
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

bool checkDirty(Link deps) {
  int stack = 0;
  Link? nextDep;
  late bool dirty;

  do {
    dirty = false;
    final dep = deps.dep;
    if (dep is IComputed) {
      if (dep.version != deps.version) {
        dirty = true;
      } else {
        final depFlags = dep.flags;
        if (depFlags & SubscriberFlags.dirty != SubscriberFlags.none) {
          dirty = dep.update();
        } else if (depFlags & SubscriberFlags.toCheckDirty !=
            SubscriberFlags.none) {
          dep.subs!.prevSub = deps;
          deps = dep.deps!;
          ++stack;
          continue;
        }
      }
    }

    if (dirty || (nextDep = deps.nextDep) == null) {
      if (stack > 0) {
        var sub = deps.sub as IComputed, shouldContinue = false;

        do {
          --stack;
          final subSubs = sub.subs!,
              prevLink = subSubs.prevSub!,
              nextDep = prevLink.nextDep;
          subSubs.prevSub = null;
          if (dirty) {
            if (sub.update()) {
              sub = prevLink.sub as IComputed;
              dirty = true;
              continue;
            }
          } else {
            sub.flags &= ~SubscriberFlags.toCheckDirty;
          }

          if (nextDep != null) {
            shouldContinue = true;
            deps = nextDep;
            break;
          }

          sub = prevLink.sub as IComputed;
          dirty = false;
        } while (stack > 0);
        if (shouldContinue) continue;
      }

      return dirty;
    }

    deps = nextDep!;
  } while (true);
}

void startTrack(Subscriber sub) {
  sub.depsTail = null;
  sub.flags = SubscriberFlags.tracking;
}

void endTrack(Subscriber sub) {
  final depsTail = sub.depsTail;
  if (depsTail != null) {
    if (depsTail.nextDep != null) {
      _clearTrack(depsTail.nextDep!);
      depsTail.nextDep = null;
    }
  } else if (sub.deps != null) {
    _clearTrack(sub.deps!);
    sub.deps = null;
  }

  sub.flags &= ~SubscriberFlags.tracking;
}

void _clearTrack(Link link) {
  Link? current = link;
  do {
    final dep = current!.dep,
        nextDep = current.nextDep,
        nextSub = current.nextSub,
        prevSub = current.prevSub;

    if (nextSub != null) {
      nextSub.prevSub = prevSub;
      current.nextSub = null;
    } else {
      dep.subsTail = prevSub;
      dep.lastTrackedId = 0;
    }

    if (prevSub != null) {
      prevSub.nextSub = nextSub;
      current.prevSub = null;
    } else {
      dep.subs = nextSub;
    }

    current.nextDep = _linkPool;
    _linkPool = current;

    if (dep.subs == null && dep is Subscriber) {
      if (dep is IEffect) {
        (dep as IEffect).flags = SubscriberFlags.none;
      } else {
        (dep as Subscriber).flags |= SubscriberFlags.dirty;
      }

      final depDeps = (dep as Subscriber).deps;
      if (depDeps != null) {
        current = depDeps;
        (dep as Subscriber).depsTail!.nextDep = nextDep;
        (dep as Subscriber).deps = (dep as Subscriber).depsTail = null;
        continue;
      }
    }

    current = nextDep;
  } while (current != null);
}
