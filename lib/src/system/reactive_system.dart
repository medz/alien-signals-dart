import 'package:alien_signals/src/system/flags.dart';
import 'package:alien_signals/src/system/link.dart';
import 'package:alien_signals/src/system/node.dart';
import 'package:alien_signals/src/system/one_way_link.dart';

abstract class ReactiveSystem {
  const ReactiveSystem();

  bool update(Node sub);
  void notify(Node sub);
  void unwatched(Node sub);

  /// Links a given dependency and subscriber if they are not already linked.
  ///
  /// - [dep] - The dependency to be linked.
  /// - [sub] - The subscriber that depends on this dependency.
  ///
  /// The newly created link object if the two are not already linked; otherwise null.
  Link? link(Node dep, Node sub) {
    final prevDep = sub.depsTail;
    if (prevDep != null && prevDep.dep == dep) return null;

    final nextDep = prevDep?.nextDep ?? sub.deps;
    if (nextDep != null && nextDep.dep == dep) return null;

    final prevSub = dep.subsTail;
    if (prevSub != null && prevSub.sub == sub && isValidLink(prevSub, sub)) {
      return null;
    }

    // dart format off
    final newLink
      = sub.depsTail
      = dep.subsTail
      = Link(dep: dep, sub: sub, prevDep: prevDep, nextDep: nextDep, prevSub: prevSub);
    // dart format on

    if (nextDep != null) nextDep.prevDep = newLink;
    if (prevDep != null) {
      prevDep.nextDep = newLink;
    } else {
      sub.deps = newLink;
    }
    if (prevSub != null) {
      prevSub.nextSub = newLink;
    } else {
      dep.subs = newLink;
    }

    return newLink;
  }

  Link? unlink(Link link, [Node? sub]) {
    sub ??= link.sub;
    final dep = link.dep;
    final prevDep = link.prevDep,
        nextDep = link.nextDep,
        prevSub = link.prevSub,
        nextSub = link.nextSub;
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
    if (nextDep != null) {
      nextDep.prevDep = prevDep;
    } else {
      sub.depsTail = prevSub;
    }
    if (prevDep != null) {
      prevDep.nextDep = nextDep;
    } else {
      sub.deps = nextDep;
    }
    if (dep.subs != null) unwatched(dep);

    return nextDep;
  }

  /// Traverses and marks subscribers starting from the provided link.
  ///
  /// It sets flags (e.g., Dirty, Pending) on each subscriber
  /// to indicate which ones require re-computation or effect processing.
  /// This function should be called after a signal's value changes.
  ///
  /// - current - The starting link from which propagation begins.
  void propagate(Link link) {
    Link? current = link, next = current.nextSub;
    OneWayLink<Link?>? branchs;
    int branchDepth = 0;
    Flags targetFlag = Flags.dirty;

    top:
    do {
      final sub = current!.sub;
      Flags subFlags = sub.flags;

      if ((subFlags & (Flags.mutable | Flags.watching)) != Flags.none) {
        // dart format off
        if ((subFlags & (Flags.running | Flags.recursed | Flags.dirty | Flags.pending)) == Flags.none) {
          // dart format on
          sub.flags = subFlags | targetFlag;
          // dart format off
        } else if ((subFlags & (Flags.running | Flags.recursed | targetFlag)) == Flags.none) {
          // dart format on
          sub.flags = subFlags | targetFlag;
          subFlags &= Flags.watching;
          // dart format off
        } else if ((subFlags & (Flags.running | Flags.recursed)) == Flags.none) {
          // dart format on
          subFlags = Flags.none;
          // dart format off
        } else if ((subFlags & Flags.running) == Flags.none) {
          // dart format on
          sub.flags = (subFlags & ~Flags.recursed) | targetFlag;
          // dart format off
        } else if (isValidLink(current, sub)) {
          // dart format off
          if ((subFlags & (Flags.dirty | Flags.pending)) == Flags.none) {
            // dart format on
            sub.flags = subFlags | Flags.recursed | targetFlag;
            subFlags &= Flags.mutable;
            // dart format off
          } else if ((subFlags & targetFlag) == Flags.none) {
            // dart format on
            sub.flags = subFlags | targetFlag;
            subFlags = Flags.none;
          } else {
            subFlags = Flags.none;
          }
        } else {
          subFlags = Flags.none;
        }

        // dart format on
        if ((subFlags & Flags.watching) != Flags.none) {
          notify(sub);
        }

        if ((subFlags & Flags.mutable) != Flags.none) {
          final subSubs = sub.subs;
          if (subSubs != null) {
            current = subSubs;
            if (subSubs.nextSub != null) {
              branchs = OneWayLink(target: next, linked: branchs);
              ++branchDepth;
              next = current.nextSub;
            }
            targetFlag = Flags.pending;
            continue;
          }
        }
      }

      if ((current = next) != null) {
        next = current!.nextSub;
        if (branchDepth == 0) {
          targetFlag = Flags.dirty;
        }
        continue;
      }

      while ((branchDepth--) > 0) {
        current = branchs?.target;
        branchs = branchs?.linked;
        if (current != null) {
          next = current.nextSub;
          if (branchDepth == 0) {
            targetFlag = Flags.dirty;
          }
          continue top;
        }
      }

      break;
    } while (true);
  }
}

extension on ReactiveSystem {
  /// Verifies whether the given link is valid for the specified subscriber.
  ///
  /// It iterates through the subscriber's link list (from sub.deps to sub.depsTail)
  /// to determine if the provided link object is part of that chain.
  bool isValidLink(Link checkLink, Node sub) {
    final depsTail = sub.depsTail;
    if (depsTail != null) {
      var link = sub.deps;
      do {
        if (link == checkLink) return true;
        if (link == depsTail) break;

        link = link?.nextDep;
      } while (link != null);
    }

    return false;
  }
}
