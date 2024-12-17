import 'types.dart';

abstract interface class IEffect implements Subscriber, Notifiable {}

abstract interface class IComputed implements Dependency, Subscriber {
  abstract int version;
  bool update();
}

abstract interface class Dependency {
  Link? subs;
  Link? subsTail;
  abstract int lastTrackedId;
}

extension type const SubscriberFlags._(int value) implements int {
  /// No flags set
  static const none = SubscriberFlags._(0);

  /// Currently tracking dependencies
  static const tracking = SubscriberFlags._(1 << 0);

  /// Can propagate changes to dependents
  static const canPropagate = SubscriberFlags._(1 << 1);

  /// Need to run inner effects
  static const runInnerEffects = SubscriberFlags._(1 << 2);

  /// Need to check if dirty
  static const toCheckDirty = SubscriberFlags._(1 << 3);

  /// Is dirty and needs update
  static const dirty = SubscriberFlags._(1 << 4);

  /// Bitwise NOT operator for flags
  SubscriberFlags operator ~() {
    return SubscriberFlags._(~value);
  }

  /// Bitwise AND operator for flags
  SubscriberFlags operator &(int other) {
    return SubscriberFlags._(value & other);
  }

  /// Bitwise OR operator for flags
  SubscriberFlags operator |(int other) {
    return SubscriberFlags._(value | other);
  }
}

abstract interface class Subscriber {
  abstract SubscriberFlags flags;
  Link? deps;
  Link? depsTail;
}

class Link {
  Link({
    required Dependency this.dep,
    required Subscriber this.sub,
    required this.version,
    this.prevSub,
    this.nextSub,
    this.nextDep,
  });

  Dependency? dep;
  Subscriber? sub;

  int version;

  Link? prevSub;
  Link? nextSub;

  Link? nextDep;
}

int _batchDepth = 0;
Notifiable? _queuedEffects;
Notifiable? _queuedEffectsTail;
Link? _linkPool;

void startBatch() {
  ++_batchDepth;
}

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

Link link(Dependency dep, Subscriber sub) {
  final currentDep = sub.depsTail;
  final nextDep = currentDep != null ? currentDep.nextDep : sub.deps;

  if (nextDep != null && nextDep.dep == dep) {
    sub.depsTail = nextDep;
    return nextDep;
  } else {
    return _linkNewDep(dep, sub, nextDep, currentDep);
  }
}

Link _linkNewDep(
  Dependency dep,
  Subscriber sub,
  Link? nextDep,
  Link? depsTail,
) {
  late Link newLink;

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
      version: 0,
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

// // See https://github.com/stackblitz/alien-signals#about-propagate-and-checkdirty-functions
// export function propagate(subs: Link): void {
//   let targetFlag = SubscriberFlags.Dirty;
//   let link = subs;
//   let stack = 0;
//   let nextSub: Link | null;

//   top: do {
//     const sub = link.sub;
//     const subFlags = sub.flags;

//     if (!(subFlags & SubscriberFlags.Tracking)) {
//       let canPropagate = !(subFlags >> 2);
//       if (!canPropagate && subFlags & SubscriberFlags.CanPropagate) {
//         sub.flags &= ~SubscriberFlags.CanPropagate;
//         canPropagate = true;
//       }
//       if (canPropagate) {
//         sub.flags |= targetFlag;
//         const subSubs = (sub as Dependency).subs;
//         if (subSubs !== null) {
//           if (subSubs.nextSub !== null) {
//             subSubs.prevSub = subs;
//             link = subs = subSubs;
//             targetFlag = SubscriberFlags.ToCheckDirty;
//             ++stack;
//           } else {
//             link = subSubs;
//             targetFlag =
//               "notify" in sub
//                 ? SubscriberFlags.RunInnerEffects
//                 : SubscriberFlags.ToCheckDirty;
//           }
//           continue;
//         }
//         if ("notify" in sub) {
//           if (queuedEffectsTail !== null) {
//             queuedEffectsTail.nextNotify = sub;
//           } else {
//             queuedEffects = sub;
//           }
//           queuedEffectsTail = sub;
//         }
//       } else if (!(sub.flags & targetFlag)) {
//         sub.flags |= targetFlag;
//       }
//     } else if (isValidLink(link, sub)) {
//       if (!(subFlags >> 2)) {
//         sub.flags |= targetFlag | SubscriberFlags.CanPropagate;
//         const subSubs = (sub as Dependency).subs;
//         if (subSubs !== null) {
//           if (subSubs.nextSub !== null) {
//             subSubs.prevSub = subs;
//             link = subs = subSubs;
//             targetFlag = SubscriberFlags.ToCheckDirty;
//             ++stack;
//           } else {
//             link = subSubs;
//             targetFlag =
//               "notify" in sub
//                 ? SubscriberFlags.RunInnerEffects
//                 : SubscriberFlags.ToCheckDirty;
//           }
//           continue;
//         }
//       } else if (!(sub.flags & targetFlag)) {
//         sub.flags |= targetFlag;
//       }
//     }

//     if ((nextSub = subs.nextSub) === null) {
//       if (stack) {
//         let dep = subs.dep;
//         do {
//           --stack;
//           const depSubs = dep.subs!;
//           const prevLink = depSubs.prevSub!;
//           depSubs.prevSub = null;
//           link = subs = prevLink.nextSub!;
//           if (subs !== null) {
//             targetFlag = stack
//               ? SubscriberFlags.ToCheckDirty
//               : SubscriberFlags.Dirty;
//             continue top;
//           }
//           dep = prevLink.dep;
//         } while (stack);
//       }
//       break;
//     }
//     if (link !== subs) {
//       targetFlag = stack ? SubscriberFlags.ToCheckDirty : SubscriberFlags.Dirty;
//     }
//     link = subs = nextSub;
//   } while (true);

//   if (!batchDepth) {
//     drainQueuedEffects();
//   }
// }

// function isValidLink(subLink: Link, sub: Subscriber) {
//   const depsTail = sub.depsTail;
//   if (depsTail !== null) {
//     let link = sub.deps!;
//     do {
//       if (link === subLink) {
//         return true;
//       }
//       if (link === depsTail) {
//         break;
//       }
//       link = link.nextDep!;
//     } while (link !== null);
//   }
//   return false;
// }

// // See https://github.com/stackblitz/alien-signals#about-propagate-and-checkdirty-functions
// export function checkDirty(deps: Link): boolean {
//   let stack = 0;
//   let dirty: boolean;
//   let nextDep: Link | null;

//   top: do {
//     dirty = false;
//     const dep = deps.dep;
//     if ("update" in dep) {
//       if (dep.version !== deps.version) {
//         dirty = true;
//       } else {
//         const depFlags = dep.flags;
//         if (depFlags & SubscriberFlags.Dirty) {
//           dirty = dep.update();
//         } else if (depFlags & SubscriberFlags.ToCheckDirty) {
//           dep.subs!.prevSub = deps;
//           deps = dep.deps!;
//           ++stack;
//           continue;
//         }
//       }
//     }
//     if (dirty || (nextDep = deps.nextDep) === null) {
//       if (stack) {
//         let sub = deps.sub as IComputed;
//         do {
//           --stack;
//           const subSubs = sub.subs!;
//           const prevLink = subSubs.prevSub!;
//           subSubs.prevSub = null;
//           if (dirty) {
//             if (sub.update()) {
//               sub = prevLink.sub as IComputed;
//               dirty = true;
//               continue;
//             }
//           } else {
//             sub.flags &= ~SubscriberFlags.ToCheckDirty;
//           }
//           deps = prevLink.nextDep!;
//           if (deps !== null) {
//             continue top;
//           }
//           sub = prevLink.sub as IComputed;
//           dirty = false;
//         } while (stack);
//       }
//       return dirty;
//     }
//     deps = nextDep;
//   } while (true);
// }

// export function startTrack(sub: Subscriber): void {
//   sub.depsTail = null;
//   sub.flags = SubscriberFlags.Tracking;
// }

// export function endTrack(sub: Subscriber): void {
//   const depsTail = sub.depsTail;
//   if (depsTail !== null) {
//     if (depsTail.nextDep !== null) {
//       clearTrack(depsTail.nextDep);
//       depsTail.nextDep = null;
//     }
//   } else if (sub.deps !== null) {
//     clearTrack(sub.deps);
//     sub.deps = null;
//   }
//   sub.flags &= ~SubscriberFlags.Tracking;
// }

// function clearTrack(link: Link): void {
//   do {
//     const dep = link.dep;
//     const nextDep = link.nextDep;
//     const nextSub = link.nextSub;
//     const prevSub = link.prevSub;

//     if (nextSub !== null) {
//       nextSub.prevSub = prevSub;
//       link.nextSub = null;
//     } else {
//       dep.subsTail = prevSub;
//       if ("lastTrackedId" in dep) {
//         dep.lastTrackedId = 0;
//       }
//     }

//     if (prevSub !== null) {
//       prevSub.nextSub = nextSub;
//       link.prevSub = null;
//     } else {
//       dep.subs = nextSub;
//     }

//     // @ts-expect-error
//     link.dep = null;
//     // @ts-expect-error
//     link.sub = null;
//     link.nextDep = linkPool;
//     linkPool = link;

//     if (dep.subs === null && "deps" in dep) {
//       if ("notify" in dep) {
//         dep.flags = SubscriberFlags.None;
//       } else {
//         dep.flags |= SubscriberFlags.Dirty;
//       }
//       const depDeps = dep.deps;
//       if (depDeps !== null) {
//         link = depDeps;
//         dep.depsTail!.nextDep = nextDep;
//         dep.deps = null;
//         dep.depsTail = null;
//         continue;
//       }
//     }

//     link = nextDep!;
//   } while (link !== null);
// }
