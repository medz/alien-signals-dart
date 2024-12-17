import 'types.dart';

/// An interface for effect subscribers that can be notified of changes.
///
/// Effects are side-effects that run when their dependencies change.
/// They implement the [Subscriber] interface to participate in the dependency tracking system.
abstract interface class IEffect implements Subscriber, Notifiable {}

/// An interface for computed values that can derive from other reactive values.
///
/// Computed values implement both [Dependency] and [Subscriber] interfaces since they
/// can both depend on other values and be depended upon.
abstract interface class IComputed implements Dependency, Subscriber {
  /// The version number of this computed value.
  ///
  /// Incremented whenever the computed value changes.
  abstract int version;

  /// Updates the computed value if necessary.
  ///
  /// Returns true if the value actually changed.
  bool update();
}

/// An interface representing a value that can be depended upon by subscribers.
///
/// Dependencies maintain a list of subscribers that need to be notified when they change.
abstract interface class Dependency {
  /// The head of the linked list of subscribers.
  Link? subs;

  /// The tail of the linked list of subscribers.
  Link? subsTail;

  /// The ID of the last tracking operation that accessed this dependency.
  int? lastTrackedId;
}

/// Flags representing different states of a subscriber.
///
/// Used for tracking the state and behavior of subscribers in the reactivity system.
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

/// An interface for objects that can subscribe to dependencies.
///
/// Subscribers maintain a list of dependencies they're tracking and flags
/// for their current state.
abstract interface class Subscriber {
  /// The current state flags of this subscriber
  abstract SubscriberFlags flags;

  /// The head of the linked list of dependencies
  Link? deps;

  /// The tail of the linked list of dependencies
  Link? depsTail;
}

/// Represents a bi-directional link in the dependency graph.
///
/// Links form a doubly-linked list between dependencies and their subscribers,
/// allowing efficient traversal and updates of the dependency graph.
class Link {
  /// Creates a new link in the dependency graph.
  ///
  /// [dep] is the dependency being linked to
  /// [sub] is the subscriber being linked to
  /// [version] is the version number of the dependency at link time
  Link({
    required this.dep,
    required this.sub,
    required this.version,
    this.prevSub,
    this.nextSub,
    this.nextDep,
  });

  /// The dependency this link connects to
  final Dependency dep;

  /// The subscriber this link connects to
  final Subscriber sub;

  /// The version of the dependency when this link was created
  int version;

  /// Previous subscriber in the linked list
  Link? prevSub;

  /// Next subscriber in the linked list
  Link? nextSub;

  /// Next dependency in the linked list
  Link? nextDep;
}

/// Current batch operation depth
int _batchDepth = 0;

/// Head of the queued effects list
Notifiable? _queuedEffects;

/// Tail of the queued effects list
Notifiable? _queuedEffectsTail;

/// Starts a batch of updates.
///
/// Batching prevents immediate execution of effects until the batch ends.
void startBatch() {
  ++_batchDepth;
}

/// Ends a batch of updates.
///
/// When the last batch ends, queued effects are executed.
void endBatch() {
  if (--_batchDepth == 0) {
    _drainQueuedEffects();
  }
}

/// Executes all queued effects.
void _drainQueuedEffects() {
  while (_queuedEffects != null) {
    final effect = _queuedEffects!,
        queuedNext = switch (effect) {
          IEffect(:final nextNotify) => nextNotify,
          _ => null,
        };

    if (queuedNext != null) {
      (effect as IEffect).nextNotify = null;
      _queuedEffects = queuedNext;
    } else {
      _queuedEffects = null;
      _queuedEffectsTail = null;
    }

    effect.notify();
  }
}

/// Creates a link between a dependency and subscriber.
///
/// Returns an existing link if one exists, otherwise creates a new one.
Link link(Dependency dep, Subscriber sub) {
  final currentDep = sub.depsTail, nextDep = currentDep?.nextDep ?? sub.deps;
  if (nextDep != null && nextDep.dep == dep) {
    sub.depsTail = nextDep;
    return nextDep;
  }

  return _linkNewDep(dep, sub, nextDep, currentDep);
}

/// Creates a new link between a dependency and subscriber.
Link _linkNewDep(
    Dependency dep, Subscriber sub, Link? nextDep, Link? depsTail) {
  late final Link newLink = Link(
    dep: dep,
    sub: sub,
    version: 0,
    nextDep: nextDep,
  );

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

/// Propagates changes through the dependency graph.
void propagate(Link subs) {
  SubscriberFlags targetFlag = SubscriberFlags.dirty;
  Link link = subs;
  int stack = 0;
  Link? nextSub;

  do {
    final sub = link.sub, subFlags = sub.flags;

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
            targetFlag = sub is Notifiable
                ? SubscriberFlags.runInnerEffects
                : SubscriberFlags.toCheckDirty;
          }

          continue;
        }
      } else if (sub.flags & targetFlag == SubscriberFlags.none) {
        sub.flags |= targetFlag;
      }
    }

    if ((nextSub = subs.nextSub) == null) {
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

    link = subs = nextSub!;
  } while (true);

  if (_batchDepth == 0) {
    _drainQueuedEffects();
  }
}

/// Checks if a link is still valid for a subscriber.
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

/// Checks if dependencies are dirty and need updating.
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

/// Starts tracking dependencies for a subscriber.
void startTrack(Subscriber sub) {
  sub.depsTail = null;
  sub.flags = SubscriberFlags.tracking;
}

/// Ends tracking dependencies for a subscriber.
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

/// Clears tracked dependencies starting from a given link.
void _clearTrack(Link link) {
  Link? current = link;

  do {
    final dep = current!.dep,
        nextDep = current.nextDep,
        nextSub = current.nextSub,
        prevSub = current.prevSub;
    current.nextDep = null;

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

    if (dep.subs == null && dep is Subscriber) {
      if (dep is Notifiable) {
        (dep as Subscriber).flags = SubscriberFlags.none;
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
