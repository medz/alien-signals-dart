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

final class Stack<T> {
  Stack({required this.value, this.prev});

  T value;
  Stack<T>? prev;
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
  ReactiveFlags operator |(int other) => ReactiveFlags._(raw | other);
}

abstract class ReactiveSystem {
  const ReactiveSystem();

  bool update(ReactiveNode sub);
  void notify(ReactiveNode sub);
  void unwatched(ReactiveNode sub);

  void link(ReactiveNode dep, ReactiveNode sub) {
    final prevDep = sub.depsTail;
    if (prevDep != null && prevDep.dep == dep) {
      return;
    }
    Link? nextDep;
    final recursedCheck = sub.flags & ReactiveFlags.recursedCheck;
    if (recursedCheck != 0) {
      nextDep = prevDep != null ? prevDep.nextDep : sub.deps;
      if (nextDep != null && nextDep.dep == dep) {
        sub.depsTail = nextDep;
        return;
      }
    }
    final prevSub = dep.subsTail;
    if (prevSub != null &&
        prevSub.sub == sub &&
        (recursedCheck == 0 || isValidLink(prevSub, sub))) {
      return;
    }
    final newLink =
        sub.depsTail =
            dep.subsTail = Link(
              dep: dep,
              sub: sub,
              prevDep: prevDep,
              nextDep: nextDep,
              prevSub: prevSub,
            );
    if (nextDep != null) {
      nextDep.prevDep = newLink;
    }
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
    final prevDep = link.prevDep;
    final nextDep = link.nextDep;
    final nextSub = link.nextSub;
    final prevSub = link.prevSub;
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
    var next = link.nextSub;
    Stack<Link?>? stack;

    top:
    do {
      final sub = link.sub;

      var flags = sub.flags;

      if (flags & (ReactiveFlags.mutable | ReactiveFlags.watching) != 0) {
        if ((flags &
                (ReactiveFlags.recursedCheck |
                    ReactiveFlags.recursed |
                    ReactiveFlags.dirty |
                    ReactiveFlags.pending)) ==
            0) {
          sub.flags = flags | ReactiveFlags.pending;
        } else if ((flags &
                (ReactiveFlags.recursedCheck | ReactiveFlags.recursed)) ==
            0) {
          flags = ReactiveFlags.none;
        } else if ((flags & ReactiveFlags.recursedCheck) == 0) {
          sub.flags = (flags & ~ReactiveFlags.recursed) | ReactiveFlags.pending;
        } else if ((flags & (ReactiveFlags.dirty | ReactiveFlags.pending)) ==
                0 &&
            isValidLink(link, sub)) {
          sub.flags = flags | ReactiveFlags.recursed | ReactiveFlags.pending;
          flags &= ReactiveFlags.mutable;
        } else {
          flags = ReactiveFlags.none;
        }

        if ((flags & ReactiveFlags.watching) != 0) {
          notify(sub);
        }

        if ((flags & ReactiveFlags.mutable) != 0) {
          final subSubs = sub.subs;
          if (subSubs != null) {
            link = subSubs;
            if (subSubs.nextSub != null) {
              stack = Stack(value: next, prev: stack);
              next = link.nextSub;
            }
            continue;
          }
        }
      }

      if ((next) != null) {
        link = next;
        next = link.nextSub;
        continue;
      }

      while (stack != null) {
        final stackValue = stack.value;
        stack = stack.prev;
        if (stackValue != null) {
          link = stackValue;
          next = link.nextSub;
          continue top;
        }
      }

      break;
    } while (true);
  }

  void startTracking(ReactiveNode sub) {
    sub.depsTail = null;
    sub.flags =
        (sub.flags &
            ~(ReactiveFlags.recursed |
                ReactiveFlags.dirty |
                ReactiveFlags.pending)) |
        ReactiveFlags.recursedCheck;
  }

  void endTracking(ReactiveNode sub) {
    final depsTail = sub.depsTail;
    var toRemove = depsTail != null ? depsTail.nextDep : sub.deps;
    while (toRemove != null) {
      toRemove = unlink(toRemove, sub);
    }
    sub.flags &= ~ReactiveFlags.recursedCheck;
  }

  bool checkDirty(Link checkLink, ReactiveNode sub) {
    Stack<Link>? stack;
    int checkDepth = 0;
    Link? link = checkLink;

    top:
    do {
      final dep = link!.dep;
      final depFlags = dep.flags;

      bool dirty = false;

      if ((sub.flags & ReactiveFlags.dirty) != 0) {
        dirty = true;
      } else if ((depFlags & (ReactiveFlags.mutable | ReactiveFlags.dirty)) ==
          (ReactiveFlags.mutable | ReactiveFlags.dirty)) {
        if (update(dep)) {
          final subs = dep.subs;
          if (subs?.nextSub != null) {
            shallowPropagate(subs!);
          }
          dirty = true;
        }
      } else if ((depFlags & (ReactiveFlags.mutable | ReactiveFlags.pending)) ==
          (ReactiveFlags.mutable | ReactiveFlags.pending)) {
        if (link.nextSub != null || link.prevSub != null) {
          stack = Stack(value: link, prev: stack);
        }
        link = dep.deps!;
        sub = dep;
        ++checkDepth;
        continue;
      }

      if (!dirty && link.nextDep != null) {
        link = link.nextDep;
        continue;
      }

      while (checkDepth > 0) {
        --checkDepth;
        final firstSub = sub.subs!;
        final hasMultipleSubs = firstSub.nextSub != null;
        if (hasMultipleSubs) {
          link = stack!.value;
          stack = stack.prev;
        } else {
          link = firstSub;
        }
        if (dirty) {
          if (update(sub)) {
            if (hasMultipleSubs) {
              shallowPropagate(firstSub);
            }
            sub = link.sub;
            continue;
          }
        } else {
          sub.flags &= ~ReactiveFlags.pending;
        }
        sub = link.sub;
        if (link.nextDep != null) {
          link = link.nextDep;
          continue top;
        }
        dirty = false;
      }

      return dirty;
    } while (true);
  }

  void shallowPropagate(Link link) {
    Link? current = link;
    do {
      final sub = current!.sub;
      final nextSub = current.nextSub;
      final subFlags = sub.flags;
      if ((subFlags & (ReactiveFlags.pending | ReactiveFlags.dirty)) ==
          ReactiveFlags.pending) {
        sub.flags = subFlags | ReactiveFlags.dirty;
        if ((subFlags & ReactiveFlags.watching) != 0) {
          notify(sub);
        }
      }
      current = nextSub;
    } while (current != null);
  }
}

extension on ReactiveSystem {
  bool isValidLink(Link checkLink, ReactiveNode sub) {
    final depsTail = sub.depsTail;
    if (depsTail != null) {
      var link = sub.deps;
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
}
