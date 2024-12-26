/// Interface for reactive effects that can subscribe to dependencies and be notified of changes
abstract interface class IEffect implements Subscriber {
  void notify();
  IEffect? nextNotify;
}

/// Interface for computed values that can track dependencies and maintain version state
abstract interface class IComputed implements Dependency, Subscriber {
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

  /// Recursed flag for indicating recursive operations
  static const recursed = SubscriberFlags._(1 << 1);

  /// Inner effects are pending and need to be processed
  static const innerEffectsPending = SubscriberFlags._(1 << 2);

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
    this.prevSub,
    this.nextSub,
    this.nextDep,
  });

  Dependency? dep;
  Subscriber? sub;

  Link? prevSub;
  Link? nextSub;

  Link? nextDep;
}

int _batchDepth = 0;
IEffect? _queuedEffects;
IEffect? _queuedEffectsTail;
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
  }

  return _linkNewDep(dep, sub, nextDep, currentDep);
}

Link _linkNewDep(
  Dependency dep,
  Subscriber sub,
  Link? nextDep,
  Link? depsTail,
) {
  Link newLink;
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
      // bool recursed = (subFlags >> 2) == 0;
      // if (!recursed) {
      //   if ((subFlags & SubscriberFlags.recursed) != 0) {
      //     sub.flags = (subFlags & ~SubscriberFlags.recursed) | targetFlag;
      //     canPropagate = true;
      //   } else if ((subFlags & targetFlag) == 0) {
      //     sub.flags = subFlags | targetFlag;
      //   }
      // } else {
      //   sub.flags = subFlags | targetFlag;
      // }

      // if (recursed) {
      //
      // ## Note
      // This is to synchronize https://github.com/stackblitz/alien-signals/commit/78aa79f5ea8926f5b8ca0daaffb3d0b9387f9140#diff-6fe6a66d9e19964283ad8fcf5ad1a9bf0e8a32a22124ef6f28474d92fda574edR145
      // In Dart, removing redundant variables has almost no improvement.
      //
      // Theoretically, whether the performance is improved is as follows:
      // Best case: before: 8 operations, after: 5 operations
      // Worst case: beforte: 8 operations, after: 10 operations
      //
      // Only in the best case can it be improved.
      if (((subFlags &
                      (SubscriberFlags.innerEffectsPending |
                          SubscriberFlags.toCheckDirty |
                          SubscriberFlags.dirty)) ==
                  0 &&
              (sub.flags = subFlags | targetFlag) != 0) ||
          ((subFlags & SubscriberFlags.recursed) != 0 &&
              ((sub.flags = subFlags & ~SubscriberFlags.recursed) |
                      targetFlag) !=
                  0)) {
        final subSubs = sub is Dependency ? (sub as Dependency).subs : null;
        if (subSubs != null) {
          if (subSubs.nextSub != null) {
            subSubs.prevSub = subs;
            link = subs = subSubs;
            targetFlag = SubscriberFlags.toCheckDirty;
            ++stack;
          } else {
            link = subSubs;
            targetFlag = sub is IEffect
                ? SubscriberFlags.innerEffectsPending
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
      } else if (subFlags & targetFlag == 0) {
        sub.flags = subFlags | targetFlag;
      }
    } else if (_isValidLink(link, sub)) {
      if ((subFlags &
              (SubscriberFlags.innerEffectsPending |
                  SubscriberFlags.toCheckDirty |
                  SubscriberFlags.dirty)) ==
          0) {
        sub.flags = subFlags | targetFlag | SubscriberFlags.recursed;
        final subSubs = (sub as Dependency).subs;
        if (subSubs != null) {
          if (subSubs.nextSub != null) {
            subSubs.prevSub = subs;
            link = subs = subSubs;
            targetFlag = SubscriberFlags.toCheckDirty;
            ++stack;
          } else {
            link = subSubs;
            targetFlag = sub is IEffect
                ? SubscriberFlags.innerEffectsPending
                : SubscriberFlags.toCheckDirty;
          }
          continue;
        }
      } else if ((subFlags & targetFlag) == 0) {
        sub.flags = subFlags | targetFlag;
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

void shallowPropagate(Link? link) {
  assert(link != null);
  do {
    final updateSub = link!.sub!;
    final updateSubFlags = updateSub.flags;
    if ((updateSubFlags &
            (SubscriberFlags.toCheckDirty | SubscriberFlags.dirty)) ==
        SubscriberFlags.toCheckDirty) {
      updateSub.flags = updateSubFlags | SubscriberFlags.dirty;
    }

    link = link.nextSub;
  } while (link != null);
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
bool checkDirty(Link? link) {
  int stack = 0;
  late bool dirty;
  Link? nextDep;

  top:
  do {
    dirty = false;
    final dep = link!.dep;
    if (dep is IComputed) {
      final depFlags = dep.flags;
      if ((depFlags & SubscriberFlags.dirty) != 0) {
        if (dep.update()) {
          final subs = dep.subs!;
          if (subs.nextSub != null) {
            shallowPropagate(subs);
          }

          dirty = true;
        }
      } else if ((depFlags & SubscriberFlags.toCheckDirty) != 0) {
        final depSubs = dep.subs!;
        if (depSubs.nextSub != null) {
          depSubs.prevSub = link;
        }

        link = dep.deps;
        ++stack;
        continue;
      }
    }
    if (dirty || (nextDep = link.nextDep) == null) {
      if (stack > 0) {
        dynamic sub = link.sub;
        do {
          --stack;
          final Link subSubs = sub.subs;
          var prevLink = subSubs.prevSub;

          if (prevLink != null) {
            subSubs.prevSub = null;
            if (dirty) {
              if (sub.update()) {
                shallowPropagate(sub.subs);
                sub = prevLink.sub;
                continue;
              } else {
                sub.flags &= ~SubscriberFlags.toCheckDirty;
              }
            }
          } else {
            if (dirty) {
              if (sub.update()) {
                sub = subSubs.sub;
                continue;
              }
            } else {
              sub.flags &= ~SubscriberFlags.toCheckDirty;
            }

            prevLink = subSubs;
          }

          link = prevLink.nextDep;
          if (link != null) {
            continue top;
          }

          sub = prevLink.sub;
          dirty = false;
        } while (stack > 0);
      }
      return dirty;
    }

    link = nextDep;
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
  while (link != null) {
    final dep = link.dep!,
        nextDep = link.nextDep,
        nextSub = link.nextSub,
        prevSub = link.prevSub;

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

    link.dep = link.sub = null;
    link.nextDep = _linkPool;
    _linkPool = link;

    if (dep.subs == null && dep is Subscriber) {
      if (dep is IEffect) {
        (dep as Subscriber).flags = SubscriberFlags.none;
      } else {
        final depFlags = (dep as Subscriber).flags;
        if ((depFlags & SubscriberFlags.dirty) == 0) {
          (dep as Subscriber).flags = depFlags | SubscriberFlags.dirty;
        }
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
  }
}
