extension type const ReactiveFlags._(int _) implements int {
  static const none = 0 as ReactiveFlags;
  static const mutable = 1 as ReactiveFlags;
  static const watching = 2 as ReactiveFlags;
  static const recursedCheck = 4 as ReactiveFlags;
  static const recursed = 8 as ReactiveFlags;
  static const dirty = 16 as ReactiveFlags;
  static const pending = 32 as ReactiveFlags;

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  ReactiveFlags operator |(int other) => _ | other as ReactiveFlags;

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  ReactiveFlags operator &(int other) => _ & other as ReactiveFlags;

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  ReactiveFlags operator ~() => ~_ as ReactiveFlags;
}

class ReactiveNode {
  ReactiveFlags flags;
  Link? deps;
  Link? depsTail;
  Link? subs;
  Link? subsTail;

  ReactiveNode(
      {required this.flags,
      this.deps,
      this.depsTail,
      this.subs,
      this.subsTail});
}

final class Link {
  int version;
  ReactiveNode dep;
  ReactiveNode sub;
  Link? prevSub;
  Link? nextSub;
  Link? prevDep;
  Link? nextDep;

  Link(
      {required this.version,
      required this.dep,
      required this.sub,
      this.prevSub,
      this.nextSub,
      this.prevDep,
      this.nextDep});
}

final class Stack<T> {
  T value;
  Stack<T>? prev;

  Stack({required this.value, this.prev});
}

({
  void Function(ReactiveNode dep, ReactiveNode sub, int version) link,
  Link? Function(Link link, [ReactiveNode sub]) unlink,
  void Function(Link link) propagate,
  void Function(Link link) shallowPropagate,
  bool Function(Link link, ReactiveNode sub) checkDirty,
}) createReactiveSystem({
  required final bool Function(ReactiveNode node) update,
  required final void Function(ReactiveNode node) notify,
  required final void Function(ReactiveNode node) unwatched,
}) {
  void link(final ReactiveNode dep, final ReactiveNode sub, final int version) {
    final prevDep = sub.depsTail;
    if (prevDep != null && prevDep.dep == dep) {
      return;
    }
    final nextDep = prevDep != null ? prevDep.nextDep : sub.deps;
    if (nextDep != null && nextDep.dep == dep) {
      nextDep.version = version;
      sub.depsTail = nextDep;
      return;
    }
    final prevSub = dep.subsTail;
    if (prevSub != null && prevSub.version == version && prevSub.sub == sub) {
      return;
    }
    final newLink = sub.depsTail = dep.subsTail = Link(
      version: version,
      dep: dep,
      sub: sub,
      prevDep: prevDep,
      nextDep: nextDep,
      prevSub: prevSub,
      nextSub: null,
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

  Link? unlink(final Link link, [ReactiveNode? sub]) {
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

  bool isValidLink(final Link checkLink, final ReactiveNode sub) {
    Link? link = sub.depsTail;
    while (link != null) {
      if (link == checkLink) {
        return true;
      }
      link = link.prevDep;
    }
    return false;
  }

  void propagate(Link link) {
    Link? next = link.nextSub;
    Stack<Link?>? stack;

    top:
    do {
      final sub = link.sub;
      ReactiveFlags flags = sub.flags;

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
      } else if ((flags & ReactiveFlags.recursedCheck) == ReactiveFlags.none) {
        sub.flags = (flags & ~ReactiveFlags.recursed) | ReactiveFlags.pending;
      } else if ((flags & (ReactiveFlags.dirty | ReactiveFlags.pending)) ==
              ReactiveFlags.none &&
          isValidLink(link, sub)) {
        sub.flags = flags | (ReactiveFlags.recursed | ReactiveFlags.pending);
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
          final nextSub = (link = subSubs).nextSub;
          if (nextSub != null) {
            stack = Stack(value: next, prev: stack);
            next = nextSub;
          }
          continue;
        }
      }

      if (next != null) {
        link = next;
        next = link.nextSub;
        continue;
      }

      while (stack != null) {
        final Stack(:value, :prev) = stack;
        stack = prev;
        if (value != null) {
          link = value;
          next = link.nextSub;
          continue top;
        }
      }

      break;
    } while (true);
  }

  void shallowPropagate(Link link) {
    Link? curr = link;
    do {
      final sub = curr!.sub;
      final flags = sub.flags;
      if ((flags & (ReactiveFlags.pending | ReactiveFlags.dirty)) ==
          ReactiveFlags.pending) {
        sub.flags = flags | ReactiveFlags.dirty;
        if ((flags & (ReactiveFlags.watching | ReactiveFlags.recursedCheck)) ==
            ReactiveFlags.watching) {
          notify(sub);
        }
      }
    } while ((curr = curr.nextSub) != null);
  }

  bool checkDirty(Link link, ReactiveNode sub) {
    Stack<Link>? stack;
    int checkDepth = 0;
    bool dirty = false;

    top:
    do {
      final dep = link.dep;
      final flags = dep.flags;

      if ((sub.flags & ReactiveFlags.dirty) != ReactiveFlags.none) {
        dirty = true;
      } else if ((flags & (ReactiveFlags.mutable | ReactiveFlags.dirty)) ==
          (ReactiveFlags.mutable | ReactiveFlags.dirty)) {
        if (update(dep)) {
          final subs = dep.subs!;
          if (subs.nextSub != null) {
            shallowPropagate(subs);
          }
          dirty = true;
        }
      } else if ((flags & (ReactiveFlags.mutable | ReactiveFlags.pending)) ==
          (ReactiveFlags.mutable | ReactiveFlags.pending)) {
        if (link.nextSub != null || link.prevSub != null) {
          stack = Stack(value: link, prev: stack);
        }
        link = dep.deps!;
        sub = dep;
        ++checkDepth;
        continue;
      }

      if (!dirty) {
        final nextDep = link.nextDep;
        if (nextDep != null) {
          link = nextDep;
          continue;
        }
      }

      while ((checkDepth--) > 0) {
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
          dirty = false;
        } else {
          sub.flags &= ~ReactiveFlags.pending;
        }
        sub = link.sub;
        final nextDep = link.nextDep;
        if (nextDep != null) {
          link = nextDep;
          continue top;
        }
      }

      return dirty;
    } while (true);
  }

  return (
    link: link,
    unlink: unlink,
    propagate: propagate,
    shallowPropagate: shallowPropagate,
    checkDirty: checkDirty,
  );
}
