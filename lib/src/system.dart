/// Interface for reactive effects that can subscribe to dependencies and be notified of changes
abstract interface class IEffect implements Subscriber {
  /// Notify the effect of a change in its dependencies.
  void notify();

  /// The next effect to be notified in the queue.
  IEffect? nextNotify;
}

/// Interface for computed values that can track dependencies and maintain version state
abstract interface class IComputed implements Dependency, Subscriber {
  /// Update the computed value if its dependencies have changed.
  ///
  /// Returns `true` if the value was updated, otherwise `false`.
  bool update();
}

/// Interface for values that can be depended on by subscribers
abstract interface class Dependency {
  /// The head of the linked list of subscribers.
  Link? subs;

  /// The tail of the linked list of subscribers.
  Link? subsTail;

  /// The ID of the last tracked dependency.
  int? lastTrackedId;
}

/// [Subscriber] flags type def.
extension type const SubscriberFlags._(int value) implements int {
  /// No flags set.
  static const none = SubscriberFlags._(0);

  /// Currently tracking dependencies.
  static const tracking = SubscriberFlags._(1 << 0);

  /// Recursed flag for indicating recursive operations.
  static const recursed = SubscriberFlags._(1 << 1);

  /// Inner effects are pending and need to be processed.
  static const innerEffectsPending = SubscriberFlags._(1 << 2);

  /// Need to check if dirty.
  static const toCheckDirty = SubscriberFlags._(1 << 3);

  /// Is dirty and needs update.
  static const dirty = SubscriberFlags._(1 << 4);

  /// Bitwise NOT operator for flags.
  ///
  /// Returns a new [SubscriberFlags] with the bitwise NOT of the current value.
  SubscriberFlags operator ~() {
    return SubscriberFlags._(~value);
  }

  /// Bitwise AND operator for flags.
  ///
  /// Takes an [int] [other] and returns a new [SubscriberFlags] with the bitwise AND of the current value and [other].
  SubscriberFlags operator &(int other) {
    return SubscriberFlags._(value & other);
  }

  /// Bitwise OR operator for flags.
  ///
  /// Takes an [int] [other] and returns a new [SubscriberFlags] with the bitwise OR of the current value and [other].
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
  /// Creates a new link between a dependency and a subscriber.
  ///
  /// The [dep] parameter is the dependency that the subscriber depends on.
  /// The [sub] parameter is the subscriber that depends on the dependency.
  /// The [prevSub] parameter is the previous subscriber in the linked list.
  /// The [nextSub] parameter is the next subscriber in the linked list.
  /// The [nextDep] parameter is the next dependency in the linked list.
  Link({
    required Dependency this.dep,
    required Subscriber this.sub,
    this.prevSub,
    this.nextSub,
    this.nextDep,
  });

  /// The dependency that the subscriber depends on.
  Dependency? dep;

  /// The subscriber that depends on the dependency.
  Subscriber? sub;

  /// The previous subscriber in the linked list.
  Link? prevSub;

  /// The next subscriber in the linked list.
  Link? nextSub;

  /// The next dependency in the linked list.
  Link? nextDep;
}

int _batchDepth = 0;
IEffect? _queuedEffects;
IEffect? _queuedEffectsTail;
Link? _linkPool;

/// Start a new batch of updates.
///
/// This function increments the batch depth counter, indicating the start of a new batch of updates.
/// Batching updates can help optimize performance by reducing the number of times the system processes changes.
///
/// {@template alien_signals.batch.example}
/// ```Example
/// final a = signal(0);
/// final b = signal(0);
///
/// effect(() {
///   print('effect run');
/// });
///
/// startBatch();
/// a.set(1);
/// b.set(1);
/// endBatch();
/// ```
/// {@endtemplate}
void startBatch() {
  ++_batchDepth;
}

/// End the current batch of updates.
///
/// This function decrements the batch depth counter. If the batch depth reaches zero, it triggers the processing
/// of any queued effects that were accumulated during the batch.
///
/// {@macro alien_signals.batch.example}
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

    // Enable for dart 3.7 version.
    // dart format off
    if ( //
        ( //
                (subFlags &
                            (SubscriberFlags.tracking |
                                SubscriberFlags.recursed |
                                SubscriberFlags.innerEffectsPending |
                                SubscriberFlags.toCheckDirty |
                                SubscriberFlags.dirty)) ==
                        0 && //
                    (sub.flags = subFlags | targetFlag) != 0 //
            ) || //
            ( //
                (subFlags &
                            (SubscriberFlags.tracking |
                                SubscriberFlags.recursed)) ==
                        SubscriberFlags.recursed && //
                    (sub.flags = (subFlags & ~SubscriberFlags.recursed) |
                            targetFlag) !=
                        0 //
            ) || //
            ( //
                (subFlags &
                            (SubscriberFlags.innerEffectsPending |
                                SubscriberFlags.toCheckDirty |
                                SubscriberFlags.dirty)) ==
                        0 && //
                    _isValidLink(link, sub) && //
                    (sub.flags =
                            subFlags | SubscriberFlags.recursed | targetFlag) !=
                        0 && //
                    sub is Dependency && //
                    (sub as Dependency).subs != null //
            ) //
        ) {
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
    } else if ( //
        (subFlags & (SubscriberFlags.tracking | targetFlag)) == 0 || //
            ((subFlags & targetFlag) == 0 && _isValidLink(link, sub)) //
        ) {
      sub.flags = subFlags | targetFlag;
    }
    // dart format on

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

/// Propagate changes through the dependency graph shallowly
///
/// This function marks subscribers as dirty if they need updates, but does not
/// recursively propagate changes through the entire dependency graph.
///
/// [link] is the starting point in the linked list of subscribers.
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
