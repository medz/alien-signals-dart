import 'package:alien_signals/src/system/link.dart';
import 'package:alien_signals/src/system/node.dart';

abstract class ReactiveSystem {
  const ReactiveSystem();

  bool update(Node sub);
  void notify(Node sub);
  void unwatched(Node sub);

  /// Links a given dependency and subscriber if they are not already linked.
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
