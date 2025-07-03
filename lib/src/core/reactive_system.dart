import 'dependency.dart';
import 'link.dart';
import 'one_way_link.dart';
import 'subscriber.dart';

abstract mixin class ReactiveSystem<Computed extends Dependency> {
  OneWayLink<Subscriber>? _queuedEffects;
  OneWayLink<Subscriber>? _queuedEffectsTail;

  /// Updates the computed subscriber's value and returns whether it changed.
  bool updateComputed(Computed computed);

  /// Handles effect notifications by processing the specified `effect`.
  bool notifyEffect(Subscriber effect);

  /// Links a given dependency and subscriber if they are not already linked.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  Link? link(Dependency dep, Subscriber sub) {
    final currentDep = sub.depsTail;
    if (currentDep != null && currentDep.dep == dep) return null;

    final nextDep = currentDep != null ? currentDep.nextDep : sub.deps;
    if (nextDep != null && nextDep.dep == dep) {
      sub.depsTail = nextDep;
      return null;
    }

    final depLastSub = dep.subsTail;
    if (depLastSub != null &&
        depLastSub.sub == sub &&
        isValidLink(depLastSub, sub)) {
      return null;
    }

    return linkNewDep(dep, sub, nextDep, currentDep);
  }

  /// Traverses and marks subscribers starting from the provided link.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void propagate(Link current) {
    Link? next = current.nextSub;
    OneWayLink<Link?>? branchs;
    int branchDepth = 0;
    int targetFlag = SubscriberFlags.dirty;

    top:
    do {
      final sub = current.sub, subFlags = sub.flags;

      if (((subFlags &
                          (SubscriberFlags.tracking |
                              SubscriberFlags.recursed |
                              SubscriberFlags.propagated)) ==
                      0 &&
                  (sub.flags =
                          subFlags | targetFlag | SubscriberFlags.notified) !=
                      0) ||
              ((subFlags & SubscriberFlags.recursed) != 0 &&
                  (subFlags & SubscriberFlags.tracking) == 0 &&
                  (sub.flags = (subFlags & ~SubscriberFlags.recursed) |
                          targetFlag |
                          SubscriberFlags.notified) !=
                      0) ||
              ((subFlags & SubscriberFlags.propagated) == 0 &&
                  isValidLink(current, sub) &&
                  ((sub.flags = subFlags |
                              SubscriberFlags.recursed |
                              targetFlag |
                              SubscriberFlags.notified) !=
                          0 &&
                      sub is Dependency &&
                      (sub as Dependency).subs != null)) // dart format on
          ) {
        final subSubs = sub is Dependency ? (sub as Dependency).subs : null;
        if (subSubs != null) {
          current = subSubs;
          if (subSubs.nextSub != null) {
            branchs = OneWayLink(next, branchs);
            ++branchDepth;
            next = current.nextSub;
            targetFlag = SubscriberFlags.pendingComputed;
          } else {
            targetFlag = (subFlags & SubscriberFlags.effect) != 0
                ? SubscriberFlags.pendingEffect
                : SubscriberFlags.pendingComputed;
          }
          continue;
        }

        if ((subFlags & SubscriberFlags.effect) != 0) {
          if (_queuedEffectsTail != null) {
            _queuedEffectsTail = _queuedEffectsTail!.linked = OneWayLink(sub);
          } else {
            _queuedEffectsTail = _queuedEffects = OneWayLink(sub);
          }
        }
      } else if ((subFlags & (SubscriberFlags.tracking | targetFlag)) == 0) {
        sub.flags = subFlags | targetFlag | SubscriberFlags.notified;
        if ((subFlags & (SubscriberFlags.effect | SubscriberFlags.notified)) ==
            SubscriberFlags.effect) {
          if (_queuedEffectsTail != null) {
            _queuedEffectsTail = _queuedEffectsTail!.linked = OneWayLink(sub);
          } else {
            _queuedEffectsTail = _queuedEffects = OneWayLink(sub);
          }
        }
      } else if ((subFlags & targetFlag) == 0 &&
          (subFlags & SubscriberFlags.propagated) != 0 &&
          isValidLink(current, sub)) {
        sub.flags = subFlags | targetFlag;
      }

      if (next != null) {
        current = next;
        next = current.nextSub;
        targetFlag = branchDepth > 0
            ? SubscriberFlags.pendingComputed
            : SubscriberFlags.dirty;
        continue;
      }

      while (branchDepth-- > 0) {
        final target = branchs?.target;
        branchs = branchs?.linked;
        if (target != null) {
          current = target;
          next = current.nextSub;
          targetFlag = branchDepth > 0
              ? SubscriberFlags.pendingComputed
              : SubscriberFlags.dirty;
          continue top;
        }
      }

      break;
    } while (true);
  }

  /// Prepares the given subscriber to track new dependencies.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void startTracking(Subscriber sub) {
    sub.depsTail = null;

    sub.flags = (sub.flags &
            ~(SubscriberFlags.notified |
                SubscriberFlags.recursed |
                SubscriberFlags.propagated)) |
        SubscriberFlags.tracking;
  }

  /// Concludes tracking of dependencies for the specified subscriber.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void endTracking(Subscriber sub) {
    final depsTail = sub.depsTail;
    if (depsTail != null) {
      final nextDep = depsTail.nextDep;
      if (nextDep != null) {
        clearTracking(nextDep);
        depsTail.nextDep = null;
      }
    } else if (sub.deps != null) {
      clearTracking(sub.deps);
      sub.deps = null;
    }

    sub.flags &= ~SubscriberFlags.tracking;
  }

  /// Updates the dirty flag for the given subscriber based on its dependencies.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool updateDirtyFlag(Subscriber sub, int flags) {
    if (checkDirty(sub.deps)) {
      sub.flags = flags | SubscriberFlags.dirty;
      return true;
    }

    sub.flags = flags & ~SubscriberFlags.pendingComputed;
    return false;
  }

  /// Updates the computed subscriber if necessary before its value is accessed.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void processComputedUpdate(Computed computed, int flags) {
    if ((flags & SubscriberFlags.dirty) != 0 ||
        checkDirty((computed as Subscriber).deps)) {
      if (updateComputed(computed)) {
        final subs = computed.subs;
        if (subs != null) shallowPropagate(subs);
      }
    } else {
      (computed as Subscriber).flags = flags & ~SubscriberFlags.pendingComputed;
    }
  }

  /// Ensures all pending internal effects for the given subscriber are processed.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void processPendingInnerEffects(Subscriber sub, int flags) {
    if ((flags & SubscriberFlags.pendingEffect) != 0) {
      sub.flags = flags & ~SubscriberFlags.pendingEffect;
      Link? link = sub.deps!;
      do {
        final dep = link!.dep;
        if (dep case final Subscriber sub
            when ((sub.flags & SubscriberFlags.effect) != 0 &&
                (sub.flags & SubscriberFlags.propagated) != 0)) {
          notifyEffect(sub);
        }

        link = link.nextDep;
      } while (link != null);
    }
  }

  /// Processes queued effect notifications after a batch operation finishes.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void processEffectNotifications() {
    while (_queuedEffects != null) {
      final effect = _queuedEffects!.target;
      if ((_queuedEffects = _queuedEffects?.linked) == null) {
        _queuedEffectsTail = null;
      }

      if (!notifyEffect(effect)) {
        effect.flags &= ~SubscriberFlags.notified;
      }
    }
  }
}

extension<Computed extends Dependency> on ReactiveSystem<Computed> {
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  Link linkNewDep(
      Dependency dep, Subscriber sub, Link? nextDep, Link? depsTail) {
    final link = Link(dep, sub, nextDep: nextDep);

    if (depsTail == null) {
      sub.deps = link;
    } else {
      depsTail.nextDep = link;
    }

    if (dep.subs == null) {
      dep.subs = link;
    } else {
      final oldTail = dep.subsTail!;
      link.prevSub = oldTail;
      oldTail.nextSub = link;
    }

    return sub.depsTail = dep.subsTail = link;
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool checkDirty(Link? current) {
    OneWayLink<Link>? prevLinks;
    int checkDepth = 0;
    top:
    do {
      final dep = current?.dep;
      if (dep case final Subscriber sub) {
        final depFlags = sub.flags;

        if ((depFlags & (SubscriberFlags.computed | SubscriberFlags.dirty)) ==
            (SubscriberFlags.computed | SubscriberFlags.dirty)) {
          if (updateComputed(dep as Computed)) {
            if (current!.nextSub != null || current.prevSub != null) {
              shallowPropagate(dep.subs);
            }

            while (checkDepth-- > 0) {
              final computed = current!.sub as Computed,
                  firstSub = computed.subs;
              if (updateComputed(computed)) {
                if (firstSub?.nextSub != null) {
                  shallowPropagate(firstSub);
                  current = prevLinks?.target;
                  prevLinks = prevLinks?.linked;
                } else {
                  current = firstSub;
                }

                continue;
              }

              if (firstSub?.nextSub != null) {
                if ((current = prevLinks?.target.nextDep) == null) {
                  return false;
                }

                prevLinks = prevLinks?.linked;
                continue top;
              }

              return false;
            }

            return true;
          }
        } else if (depFlags &
                (SubscriberFlags.pendingComputed | SubscriberFlags.computed) ==
            (SubscriberFlags.pendingComputed | SubscriberFlags.computed)) {
          sub.flags = depFlags & ~SubscriberFlags.pendingComputed;
          if (current!.nextSub != null || current.prevSub != null) {
            prevLinks = OneWayLink(current, prevLinks);
          }

          ++checkDepth;
          current = sub.deps;
          continue;
        }
      }

      if ((current = current?.nextDep) == null) return false;
    } while (true);
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void shallowPropagate(Link? link) {
    while (link != null) {
      final sub = link.sub, subFlags = sub.flags;
      if ((subFlags &
              (SubscriberFlags.pendingComputed | SubscriberFlags.dirty)) ==
          SubscriberFlags.pendingComputed) {
        sub.flags = subFlags | SubscriberFlags.dirty | SubscriberFlags.notified;
        if ((subFlags & (SubscriberFlags.effect | SubscriberFlags.notified)) ==
            SubscriberFlags.effect) {
          if (_queuedEffectsTail != null) {
            _queuedEffectsTail = _queuedEffectsTail!.linked = OneWayLink(sub);
          } else {
            _queuedEffectsTail = _queuedEffects = OneWayLink(sub);
          }
        }
      }
      link = link.nextSub;
    }
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool isValidLink(Link checkLink, Subscriber sub) {
    final depsTail = sub.depsTail;
    if (depsTail != null) {
      Link? link = sub.deps;
      do {
        if (link == checkLink) return true;
        if (link == depsTail) break;
        link = link?.nextDep;
      } while (link != null);
    }

    return false;
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void clearTracking(Link? link) {
    while (link != null) {
      final dep = link.dep,
          nextDep = link.nextDep,
          nextSub = link.nextSub,
          prevSub = link.prevSub;
      if (nextSub != null) {
        nextSub.prevSub = prevSub;
      } else {
        dep.subsTail = prevSub;
      }

      if (prevSub != null) {
        prevSub.nextSub = nextSub;
      } else {
        dep.subs = nextSub;
      }

      if (dep case final Subscriber sub when dep.subs == null) {
        if (sub.flags & SubscriberFlags.dirty == 0) {
          sub.flags |= SubscriberFlags.dirty;
        }

        if (sub.deps != null) {
          link = sub.deps;
          sub.depsTail?.nextDep = nextDep;
          sub.deps = sub.depsTail = null;
          continue;
        }
      }

      link = nextDep;
    }
  }
}
