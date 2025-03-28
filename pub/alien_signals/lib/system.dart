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

abstract mixin class Dependency {
  Link? subs;
  Link? subsTail;
}

abstract mixin class Subscriber {
  abstract int flags;
  Link? deps;
  Link? depsTail;
}

class Link {
  Link(this.dep, this.sub);

  final Dependency dep;
  final Subscriber sub;
  Link? prevSub;
  Link? nextDep;
  Link? nextSub;
}

class _OneWayLink<T> {
  _OneWayLink(this.target, [this.linked]);

  final T target;
  _OneWayLink<T>? linked;
}

typedef _System<Computed> = ({
  Link? Function(Dependency, Subscriber) link,
  void Function(Link) propagate,
  bool Function(Subscriber, int) updateDirtyFlag,
  void Function(Subscriber) startTracking,
  void Function(Subscriber) endTracking,
  void Function(Computed, int) processComputedUpdate,
  void Function(Subscriber, int) processPendingInnerEffects,
  void Function() processEffectNotifications,
});

typedef _Updates<T1, T2> = bool Function(T1, T2);

T _infer<T>(T value) => value;

final createReactiveSystem = _infer(<Computed>({
  required _Updates<_System<Computed>, Computed> updateComputed,
  required _Updates<_System<Computed>, Subscriber> notifyEffect,
}) {
  late final _System<Computed> system;
  final notifyBuffer = <int, Subscriber?>{};
  int notifyIndex = 0, notifyBufferLength = 0;

  Link linkNewDep(
      Dependency dep, Subscriber sub, Link? nextDep, Link? depsTail) {
    final newLink = Link(dep, sub)..nextDep = nextDep;
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

  void shallowPropagate(Link link) {
    Link? current = link;
    do {
      final sub = current!.sub, subFlags = sub.flags;
      if ((subFlags &
              (SubscriberFlags.pendingComputed | SubscriberFlags.dirty)) ==
          SubscriberFlags.pendingComputed) {
        sub.flags = subFlags | SubscriberFlags.dirty | SubscriberFlags.notified;
        if ((subFlags & (SubscriberFlags.effect | SubscriberFlags.notified)) ==
            SubscriberFlags.effect) {
          notifyBuffer[notifyBufferLength++] = sub;
        }
      }

      current = current.nextSub;
    } while (current != null);
  }

  bool checkDirty(Link current) {
    _OneWayLink<Link>? prevLinks;
    int checkDepth = 0;
    late bool dirty;

    top:
    do {
      dirty = false;
      final dep = current.dep;

      if (dep is Subscriber) {
        final depFlags = (dep as Subscriber).flags;
        if ((depFlags & (SubscriberFlags.computed | SubscriberFlags.dirty)) ==
            (SubscriberFlags.computed | SubscriberFlags.dirty)) {
          if (updateComputed(system, dep as Computed)) {
            final subs = dep.subs;
            if (subs?.nextSub != null) {
              shallowPropagate(subs!);
            }

            dirty = true;
          }
        } else if ((depFlags &
                (SubscriberFlags.computed | SubscriberFlags.pendingComputed)) ==
            (SubscriberFlags.computed | SubscriberFlags.pendingComputed)) {
          if (current.nextSub != null || current.prevSub != null) {
            prevLinks = _OneWayLink(current, prevLinks);
          }

          current = (dep as Subscriber).deps!;
          ++checkDepth;
          continue;
        }
      }

      if (!dirty && current.nextDep != null) {
        current = current.nextDep!;
        continue;
      }

      while (checkDepth > 0) {
        --checkDepth;
        final sub = current.sub as Computed;
        final firstSub = (sub as Dependency).subs!;
        if (dirty) {
          if (updateComputed(system, sub)) {
            if (firstSub.nextSub != null) {
              current = prevLinks!.target;
              prevLinks = prevLinks.linked;
              shallowPropagate(firstSub);
            } else {
              current = firstSub;
            }
            continue;
          }
        } else {
          (sub as Subscriber).flags &= ~SubscriberFlags.pendingComputed;
        }

        if (firstSub.nextSub != null) {
          current = prevLinks!.target;
          prevLinks = prevLinks.linked;
        } else {
          current = firstSub;
        }

        if (current.nextDep != null) {
          current = current.nextDep!;
          continue top;
        }

        dirty = false;
      }

      return dirty;
    } while (true);
  }

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

  void clearTracking(Link link) {
    Link? current = link;
    do {
      final dep = current!.dep,
          nextDep = current.nextDep,
          nextSub = current.nextSub,
          prevSub = current.prevSub;
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

      if (dep.subs == null && dep is Subscriber) {
        final depFlags = (dep as Subscriber).flags;
        if ((depFlags & SubscriberFlags.dirty) == 0) {
          (dep as Subscriber).flags = depFlags | SubscriberFlags.dirty;
        }

        final depDeps = (dep as Subscriber).deps;
        if (depDeps != null) {
          current = depDeps;
          (dep as Subscriber).depsTail!.nextDep = nextDep;
          (dep as Subscriber).deps = null;
          (dep as Subscriber).depsTail = null;
          continue;
        }
      }

      current = nextDep;
    } while (current != null);
  }

  Link? link(Dependency dep, Subscriber sub) {
    final currentDep = sub.depsTail;
    if (currentDep != null && currentDep.dep == dep) {
      return null;
    }

    final nextDep = currentDep != null ? currentDep.nextDep : sub.deps;
    if (nextDep != null && nextDep.dep == dep) {
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

  void propagate(Link current) {
    Link? next = current.nextSub;
    _OneWayLink<Link?>? branchs;
    int branchDepth = 0, targetFlag = SubscriberFlags.dirty;

    top:
    do {
      final sub = current.sub, subFlags = sub.flags;
      bool shouldNotify = false;

      if ((subFlags &
              (SubscriberFlags.tracking |
                  SubscriberFlags.recursed |
                  SubscriberFlags.propagated)) ==
          0) {
        sub.flags = subFlags | targetFlag | SubscriberFlags.notified;
        shouldNotify = true;
      } else if ((subFlags & SubscriberFlags.recursed) != 0 &&
          (subFlags & SubscriberFlags.tracking) == 0) {
        sub.flags = (subFlags & ~SubscriberFlags.recursed) |
            targetFlag |
            SubscriberFlags.notified;
        shouldNotify = true;
      } else if ((subFlags & SubscriberFlags.propagated) == 0 &&
          isValidLink(current, sub)) {
        sub.flags = subFlags |
            SubscriberFlags.recursed |
            targetFlag |
            SubscriberFlags.notified;
        shouldNotify = sub is Dependency && (sub as Dependency).subs != null;
      }

      if (shouldNotify) {
        if (sub case Dependency(subs: final subSubs) when subSubs != null) {
          current = subSubs;
          if (subSubs.nextSub != null) {
            branchs = _OneWayLink(next, branchs);
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
          notifyBuffer[notifyBufferLength++] = sub;
        }
      } else if ((subFlags & (SubscriberFlags.tracking | targetFlag)) == 0) {
        sub.flags = subFlags | targetFlag | SubscriberFlags.notified;
        if ((subFlags & (SubscriberFlags.effect | SubscriberFlags.notified)) ==
            SubscriberFlags.effect) {
          notifyBuffer[notifyBufferLength++] = sub;
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

  void startTracking(Subscriber sub) {
    sub.depsTail = null;
    sub.flags = (sub.flags &
            ~(SubscriberFlags.notified |
                SubscriberFlags.recursed |
                SubscriberFlags.propagated)) |
        SubscriberFlags.tracking;
  }

  void endTracking(Subscriber sub) {
    final depsTail = sub.depsTail;
    if (depsTail != null) {
      final nextDep = depsTail.nextDep;
      if (nextDep != null) {
        clearTracking(nextDep);
        depsTail.nextDep = null;
      }
    } else if (sub.deps != null) {
      clearTracking(sub.deps!);
      sub.deps = null;
    }

    sub.flags &= ~SubscriberFlags.tracking;
  }

  bool updateDirtyFlag(Subscriber sub, int flags) {
    if (checkDirty(sub.deps!)) {
      sub.flags = flags | SubscriberFlags.dirty;
      return true;
    }

    sub.flags = flags & ~SubscriberFlags.pendingComputed;
    return false;
  }

  void processComputedUpdate(Computed computed, int flags) {
    if (computed is! Dependency || computed is! Subscriber) {
      throw AssertionError('Computed must be a Dependency and Subscriber');
    }

    if ((flags & SubscriberFlags.dirty) != 0 ||
        checkDirty((computed as Subscriber).deps!)) {
      if (updateComputed(system, computed)) {
        final subs = computed.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    } else {
      (computed as Subscriber).flags = flags & ~SubscriberFlags.pendingComputed;
    }
  }

  void processPendingInnerEffects(Subscriber sub, int flags) {
    if ((flags & SubscriberFlags.pendingEffect) != 0) {
      sub.flags = flags & ~SubscriberFlags.pendingEffect;
      Link? link = sub.deps;
      do {
        final dep = link?.dep is Subscriber ? (link!.dep as Subscriber) : null;
        if (dep != null &&
            (dep.flags & SubscriberFlags.effect) != 0 &&
            (dep.flags & SubscriberFlags.propagated) != 0) {
          notifyEffect(system, dep);
        }

        link = link?.nextDep;
      } while (link != null);
    }
  }

  void processEffectNotifications() {
    while (notifyIndex < notifyBufferLength) {
      final effect = notifyBuffer[notifyIndex]!;
      notifyBuffer[notifyIndex++] = null;
      if (!notifyEffect(system, effect)) {
        effect.flags &= ~SubscriberFlags.notified;
      }
    }

    notifyIndex = 0;
    notifyBufferLength = 0;
  }

  return system = (
    link: link,
    propagate: propagate,
    startTracking: startTracking,
    endTracking: endTracking,
    updateDirtyFlag: updateDirtyFlag,
    processComputedUpdate: processComputedUpdate,
    processPendingInnerEffects: processPendingInnerEffects,
    processEffectNotifications: processEffectNotifications
  );
});
