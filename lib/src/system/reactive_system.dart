import 'package:alien_signals/src/system/link.dart';
import 'package:alien_signals/src/system/node.dart';

abstract class ReactiveSystem {
  const ReactiveSystem();

  bool update(Node sub);
  void notify(Node sub);
  void unwatched(Node sub);

  /// Links a given dependency and subscriber if they are not already linked.
  ///
  /// - dep - The dependency to be linked.
  /// - sub - The subscriber that depends on this dependency.
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
  void propagate() {}
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
