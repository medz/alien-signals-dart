abstract class ReactiveNode {
  ReactiveNode({
    this.deps,
    this.depsTail,
    this.subs,
    this.subsTail,
    required this.flags,
  });

  Link? deps;
  Link? depsTail;
  Link? subs;
  Link? subsTail;
  ReactiveFlags flags;
}

class Link {
  Link({
    required this.dep,
    required this.sub,
    this.prevSub,
    this.nextSub,
    this.prevDep,
    this.nextDep,
  });

  ReactiveNode dep;
  ReactiveNode sub;
  Link? prevSub;
  Link? nextSub;
  Link? prevDep;
  Link? nextDep;
}

final class _Stack<T> {
  _Stack({required this.value, this.prev});

  T value;
  _Stack<T>? prev;
}

extension type const ReactiveFlags._(int raw) implements int {
  static const none = ReactiveFlags._(0);
  static const mutable = ReactiveFlags._(1 << 0);
  static const watching = ReactiveFlags._(1 << 1);
  static const recursedCheck = ReactiveFlags._(1 << 2);
  static const recursed = ReactiveFlags._(1 << 3);
  static const dirty = ReactiveFlags._(1 << 4);
  static const pending = ReactiveFlags._(1 << 5);

  ReactiveFlags operator &(int other) => ReactiveFlags._(raw & other);
  ReactiveFlags operator |(int other) => ReactiveFlags._(raw & other);
}

abstract class ReactiveSystem {
  ReactiveSystem();

  bool update(ReactiveNode sub);
  void notify(ReactiveNode sub);
  void unwatched(ReactiveNode sub);

  void link(ReactiveNode dep, ReactiveNode sub) {
    final prevDep = sub.subsTail;
    if (prevDep != null && prevDep.dep == dep) return;

    Link? nextDep;
    final recursedCheck = sub.flags & ReactiveFlags.recursedCheck;
    if (recursedCheck != ReactiveFlags.none) {
      nextDep = prevDep != null ? prevDep.nextDep : sub.deps;
      if (nextDep != null && nextDep.dep == dep) {
        sub.depsTail = nextDep;
        return;
      }
    }

    final prevSub = dep.subsTail;
    if (prevSub != null &&
        prevSub.sub == sub &&
        (recursedCheck == ReactiveFlags.none || isValidLink(prevSub, sub))) {
      return;
    }

    // dart format off
    final newLink
      = sub.depsTail
      = dep.subsTail
      = Link(dep: dep, sub: sub, prevSub: prevSub, prevDep: prevDep, nextDep: nextDep);
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
  }

  Link? unlink(Link link, [ReactiveNode? sub]) {
    sub ??= link.sub;
    final dep = link.dep;
    final prevDep = link.prevDep,
        nextDep = link.nextDep,
        prevSub = link.prevSub,
        nextSub = link.nextSub;

    if (nextDep != null) {
      nextDep.prevDep = prevDep;
    } else {
      sub.depsTail = prevDep;
    }
    if (prevDep != null) {
      prevDep.nextDep = nextDep;
    } else {
      sub.deps = nextDep;
    }
    if (nextSub != null) {
      nextSub.prevSub = prevSub;
    } else {
      dep.subsTail = prevSub;
    }
    if (prevSub != null) {
      prevSub.nextSub = nextSub;
    } else if ((dep.subs = nextSub) == null) {
      unwatched(dep);
    }

    return nextDep;
  }

  void propagate(Link link) {
    Link? next = link.nextSub;
    _Stack<Link?>? stack;

    top:
    do {
      final sub = link.sub;
      ReactiveFlags flags = sub.flags;

      if ((flags & (ReactiveFlags.mutable | ReactiveFlags.watching)) !=
          ReactiveFlags.none) {
        if ((flags &
                (ReactiveFlags.recursedCheck |
                    ReactiveFlags.recursed |
                    ReactiveFlags.dirty |
                    ReactiveFlags.pending)) ==
            ReactiveFlags.none) {
          sub.flags = flags | ReactiveFlags.pending;
        } else if ((flags &
                (ReactiveFlags.recursedCheck | ReactiveFlags.recursed)) ==
            ReactiveFlags.none) {
          flags = ReactiveFlags.none;
        } else if ((flags & ReactiveFlags.recursedCheck) ==
            ReactiveFlags.none) {
          sub.flags = (flags & ~ReactiveFlags.recursed) | ReactiveFlags.pending;
        } else if ((flags & (ReactiveFlags.dirty | ReactiveFlags.pending)) ==
                ReactiveFlags.none &&
            isValidLink(link, sub)) {
          sub.flags = flags | ReactiveFlags.recursed | ReactiveFlags.pending;
          flags &= ReactiveFlags.mutable;
        } else {
          flags = ReactiveFlags.none;
        }

        if ((flags & ReactiveFlags.watching) != ReactiveFlags.none) {
          notify(sub);
        }

        if ((flags & ReactiveFlags.mutable) != ReactiveFlags.none) {
          final subSubs = sub.subs;
          if (subSubs != null) {
            link = subSubs;
            if (subSubs.nextSub != null) {
              stack = _Stack(value: next, prev: stack);
              next = link.nextSub;
            }
            continue;
          }
        }
      }

      if (next != null) {
        link = next;
        next = link.nextSub;
        continue;
      }

      while (stack != null) {
        final stackLink = stack.value;
        stack = stack.prev;
        if (stackLink != null) {
          link = stackLink;
          next = link.nextSub;
          continue top;
        }
      }

      break;
    } while (true);
  }
}

extension on ReactiveSystem {
  bool isValidLink(Link checkLink, ReactiveNode sub) {
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
