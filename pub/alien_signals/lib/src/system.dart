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
  Link({
    required this.dep,
    required this.sub,
    this.prevSub,
    this.nextSub,
    this.nextDep,
  });

  final Dependency dep;
  final Subscriber sub;

  Link? prevSub;
  Link? nextSub;
  Link? nextDep;
}

abstract class ReactiveSystem<Computed extends Dependency> {
  ReactiveSystem();

  Subscriber? _queuedEffects;
  Subscriber? _queuedEffectsTail;

  /// Updates the computed subscriber's value and returns whether it changed.
  ///
  /// This function should be called when a computed subscriber is marked as Dirty.
  /// The computed subscriber's getter function is invoked, and its value is updated.
  /// If the value changes, the new value is stored, and the function returns `true`.
  ///
  /// * [computed] - The computed subscriber to update.
  ///
  /// Returns `true` if the computed subscriber's value changed; otherwise `false`.
  bool updateComputed(Computed computed);

  /// Handles effect notifications by processing the specified `effect`.
  ///
  /// When an `effect` first receives any of the following flags:
  ///   - `dirty`
  ///   - `pendingComputed`
  ///   - `pendingEffect`
  /// this method will process them and return `true` if the flags are successfully handled.
  /// If not fully handled, future changes to these flags will trigger additional calls
  /// until the method eventually returns `true`.
  bool notifyEffect(Subscriber effect);

  /// Links a given dependency and subscriber if they are not already linked.
  ///
  /// [dep] - The dependency to be linked.
  /// [sub] - The subscriber that depends on this dependency.
  /// Returns the newly created link object if the two are not already linked;
  /// otherwise null.
  Link? link(Dependency dep, Subscriber sub) {
    final currentDep = sub.depsTail;
    if (currentDep != null && currentDep.dep == dep) {
      return null;
    }
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
  ///
  /// It sets flags (e.g., Dirty, PendingComputed, PendingEffect) on each subscriber
  /// to indicate which ones require re-computation or effect processing.
  /// This function should be called after a signal's value changes.
  ///
  /// [link] - The starting link from which propagation begins.
  void propagate(Link? link) {
    if (link == null) return;

    int targetFlag = SubscriberFlags.dirty;
    Link? subs = link;
    int stack = 0;

    top:
    do {
      final sub = link!.sub;
      final subFlags = sub.flags;

      if (((subFlags &
                      (SubscriberFlags.tracking |
                          SubscriberFlags.recursed |
                          SubscriberFlags.propagated)) ==
                  0 &&
              (sub.flags = subFlags | targetFlag | SubscriberFlags.notified) !=
                  0) ||
          ((subFlags & SubscriberFlags.recursed) != 0 &&
              (subFlags & SubscriberFlags.tracking) == 0 &&
              (sub.flags = (subFlags & ~SubscriberFlags.recursed) |
                      targetFlag |
                      SubscriberFlags.notified) !=
                  0) ||
          ((subFlags & SubscriberFlags.propagated) == 0 &&
              isValidLink(link, sub) &&
              (sub.flags = subFlags |
                      SubscriberFlags.recursed |
                      targetFlag |
                      SubscriberFlags.notified) !=
                  0 &&
              sub is Dependency &&
              (sub as Dependency).subs != null)) {
        final subSubs = sub is Dependency ? (sub as Dependency).subs : null;
        if (subSubs != null) {
          if (subSubs.nextSub != null) {
            subSubs.prevSub = subs;
            link = subs = subSubs;
            targetFlag = SubscriberFlags.pendingComputed;
            ++stack;
          } else {
            link = subSubs;
            targetFlag = (subFlags & SubscriberFlags.effect) != 0
                ? SubscriberFlags.pendingEffect
                : SubscriberFlags.pendingComputed;
          }
          continue;
        }
        if ((subFlags & SubscriberFlags.effect) != 0) {
          if (_queuedEffectsTail != null) {
            _queuedEffectsTail!.depsTail!.nextDep = sub.deps;
          } else {
            _queuedEffects = sub;
          }
          _queuedEffectsTail = sub;
        }
      } else if ((subFlags & (SubscriberFlags.tracking | targetFlag)) == 0) {
        sub.flags = subFlags | targetFlag | SubscriberFlags.notified;
        if ((subFlags & (SubscriberFlags.effect | SubscriberFlags.notified)) ==
            SubscriberFlags.effect) {
          if (_queuedEffectsTail != null) {
            _queuedEffectsTail!.depsTail!.nextDep = sub.deps;
          } else {
            _queuedEffects = sub;
          }
          _queuedEffectsTail = sub;
        }
      } else if ((subFlags & targetFlag) == 0 &&
          (subFlags & SubscriberFlags.propagated) != 0 &&
          isValidLink(link, sub)) {
        sub.flags = subFlags | targetFlag;
      }

      if ((link = subs?.nextSub) != null) {
        subs = link;
        targetFlag = (stack > 0)
            ? SubscriberFlags.pendingComputed
            : SubscriberFlags.dirty;
        continue;
      }

      while (stack > 0) {
        --stack;
        final dep = subs?.dep;
        final depSubs = dep?.subs;
        subs = depSubs?.prevSub;
        depSubs?.prevSub = null;
        if ((link = subs?.nextSub) != null) {
          subs = link;
          targetFlag = (stack > 0)
              ? SubscriberFlags.pendingComputed
              : SubscriberFlags.dirty;
          continue top;
        }
      }

      break;
    } while (true);
  }

  /// Prepares the given subscriber to track new dependencies.
  ///
  /// It resets the subscriber's internal pointers (e.g., depsTail) and
  /// sets its flags to indicate it is now tracking dependency links.
  ///
  /// [sub] - The subscriber to start tracking.
  void startTracking(Subscriber sub) {
    sub.depsTail = null;
    sub.flags = (sub.flags &
            ~(SubscriberFlags.notified |
                SubscriberFlags.recursed |
                SubscriberFlags.propagated)) |
        SubscriberFlags.tracking;
  }

  /// Concludes tracking of dependencies for the specified subscriber.
  ///
  /// It clears or unlinks any tracked dependency information, then
  /// updates the subscriber's flags to indicate tracking is complete.
  ///
  /// [sub] - The subscriber whose tracking is ending.
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
  ///
  /// If the subscriber has any pending computeds, this function sets the Dirty flag
  /// and returns `true`. Otherwise, it clears the PendingComputed flag and returns `false`.
  ///
  /// [sub] - The subscriber to update.
  /// [flags] - The current flag set for this subscriber.
  ///
  /// Returns `true` if the subscriber is marked as Dirty; otherwise `false`.
  bool updateDirtyFlag(Subscriber sub, int flags) {
    if (checkDirty(sub.deps!)) {
      sub.flags = flags | SubscriberFlags.dirty;
      return true;
    } else {
      sub.flags = flags & ~SubscriberFlags.pendingComputed;
      return false;
    }
  }

  /// Updates the computed subscriber if necessary before its value is accessed.
  ///
  /// If the subscriber is marked Dirty or PendingComputed, this function runs
  /// the provided updateComputed logic and triggers a shallowPropagate for any
  /// downstream subscribers if an actual update occurs.
  ///
  /// [computed] - The computed subscriber to update.
  /// [flags] - The current flag set for this subscriber.
  void processComputedUpdate(Computed computed, int flags) {
    if ((flags & SubscriberFlags.dirty) != 0 ||
        (checkDirty((computed as Subscriber).deps)
            ? true
            : ((flags &= ~SubscriberFlags.pendingComputed) == 0))) {
      if (updateComputed(computed)) {
        final subs = computed.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    }
  }

  /// Ensures all pending internal effects for the given subscriber are processed.
  ///
  /// This should be called after an effect decides not to re-run itself but may still
  /// have dependencies flagged with PendingEffect. If the subscriber is flagged with
  /// PendingEffect, this function clears that flag and invokes `notifyEffect` on any
  /// related dependencies marked as Effect and Propagated, processing pending effects.
  ///
  /// Parameters:
  ///   - sub: The subscriber which may have pending effects.
  ///   - flags: The current flags on the subscriber to check.
  void processPendingInnerEffects(Subscriber sub, int flags) {
    if ((flags & SubscriberFlags.pendingEffect) != 0) {
      sub.flags = flags & ~SubscriberFlags.pendingEffect;
      Link? link = sub.deps;
      do {
        final dep = link!.dep;
        if (dep is Subscriber &&
            ((dep as Subscriber).flags & SubscriberFlags.effect) != 0 &&
            ((dep as Subscriber).flags & SubscriberFlags.propagated) != 0) {
          notifyEffect(dep as Subscriber);
        }
        link = link.nextDep;
      } while (link != null);
    }
  }

  /// Processes queued effect notifications after a batch operation finishes.
  ///
  /// Iterates through all queued effects, calling notifyEffect on each.
  /// If an effect remains partially handled, its flags are updated, and future
  /// notifications may be triggered until fully handled.
  void processEffectNotifications() {
    while (_queuedEffects != null) {
      final effect = _queuedEffects;
      final depsTail = effect!.depsTail!;
      final queuedNext = depsTail.nextDep;
      if (queuedNext != null) {
        depsTail.nextDep = null;
        _queuedEffects = queuedNext.sub;
      } else {
        _queuedEffects = null;
        _queuedEffectsTail = null;
      }
      if (!notifyEffect(effect)) {
        effect.flags &= ~SubscriberFlags.notified;
      }
    }
  }
}

extension<Computed extends Dependency> on ReactiveSystem<Computed> {
  Link linkNewDep(
      Dependency dep, Subscriber sub, Link? nextDep, Link? depsTail) {
    final newLink = Link(dep: dep, sub: sub, nextDep: nextDep);

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

  bool checkDirty(Link? link) {
    int stack = 0;
    bool dirty = false;

    top:
    do {
      dirty = false;
      final dep = link!.dep;

      if (dep is Subscriber) {
        final depFlags = (dep as Subscriber).flags;
        if ((depFlags & (SubscriberFlags.computed | SubscriberFlags.dirty)) ==
            (SubscriberFlags.computed | SubscriberFlags.dirty)) {
          if (updateComputed(dep as Computed)) {
            final subs = dep.subs;
            if (subs?.nextSub != null) {
              shallowPropagate(subs);
            }
            dirty = true;
          }
        } else if ((depFlags &
                (SubscriberFlags.computed | SubscriberFlags.pendingComputed)) ==
            (SubscriberFlags.computed | SubscriberFlags.pendingComputed)) {
          final depSubs = dep.subs!;
          if (depSubs.nextSub != null) {
            depSubs.prevSub = link;
          }
          link = (dep as Subscriber).deps;
          ++stack;
          continue;
        }
      }

      if (!dirty && link.nextDep != null) {
        link = link.nextDep;
        continue;
      }

      if (stack > 0) {
        Subscriber? sub = link.sub;
        do {
          --stack;
          final subSubs = (sub as Dependency).subs;

          if (dirty) {
            if (updateComputed(sub as Computed)) {
              if ((link = subSubs?.prevSub) != null) {
                subSubs!.prevSub = null;
                shallowPropagate((sub as Computed).subs);
                sub = link?.sub;
              } else {
                sub = subSubs?.sub;
              }
              continue;
            }
          } else {
            sub!.flags &= ~SubscriberFlags.pendingComputed;
          }

          if ((link = subSubs?.prevSub) != null) {
            subSubs!.prevSub = null;
            if (link!.nextDep != null) {
              link = link.nextDep;
              continue top;
            }
            sub = link.sub;
          } else {
            if ((link = subSubs?.nextDep) != null) {
              continue top;
            }
            sub = subSubs?.sub;
          }

          dirty = false;
        } while (stack > 0);
      }

      return dirty;
    } while (true);
  }

  void shallowPropagate(Link? link) {
    if (link == null) return;
    do {
      final sub = link!.sub;
      final subFlags = sub.flags;
      if ((subFlags &
              (SubscriberFlags.pendingComputed | SubscriberFlags.dirty)) ==
          SubscriberFlags.pendingComputed) {
        sub.flags = subFlags | SubscriberFlags.dirty | SubscriberFlags.notified;
        if ((subFlags & (SubscriberFlags.effect | SubscriberFlags.notified)) ==
            SubscriberFlags.effect) {
          if (_queuedEffectsTail != null) {
            _queuedEffectsTail!.depsTail!.nextDep = sub.deps;
          } else {
            _queuedEffects = sub;
          }
          _queuedEffectsTail = sub;
        }
      }
      link = link.nextSub;
    } while (link != null);
  }

  bool isValidLink(Link checkLink, Subscriber sub) {
    final depsTail = sub.depsTail;
    if (depsTail != null) {
      Link? link = sub.deps;
      do {
        if (link == checkLink) {
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

  void clearTracking(Link? link) {
    if (link == null) return;
    do {
      final dep = link!.dep;
      final nextDep = link.nextDep;
      final nextSub = link.nextSub;
      final prevSub = link.prevSub;

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
        final flags = sub.flags;
        if ((flags & SubscriberFlags.dirty) == 0) {
          sub.flags = flags | SubscriberFlags.dirty;
        }

        final deps = sub.deps;
        if (deps != null) {
          link = deps;
          sub.depsTail?.nextDep = nextDep;
          sub.deps = null;
          sub.depsTail = null;
          continue;
        }
      }

      link = nextDep;
    } while (link != null);
  }
}
