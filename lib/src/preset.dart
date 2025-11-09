import 'package:alien_signals/system.dart';

class LinkedEffect extends ReactiveNode {
  LinkedEffect? nextEffect;

  LinkedEffect(
      {required super.flags,
      super.deps,
      super.depsTail,
      super.subs,
      super.subsTail});
}

class SignalNode<T> extends ReactiveNode {
  T currentValue;
  T pendingValue;

  SignalNode(
      {required super.flags,
      required this.currentValue,
      required this.pendingValue});
}

class ComputedNode<T> extends ReactiveNode {
  final T Function(T?) getter;
  T? value;

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  bool run() => value != (value = getter(value));

  ComputedNode({required super.flags, required this.getter});
}

class EffectNode extends LinkedEffect {
  final void Function() fn;

  EffectNode({required super.flags, required this.fn});
}

int cycle = 0, batchDepth = 0;
ReactiveNode? activeSub;
LinkedEffect? queuedEffects;
LinkedEffect? queuedEffectsTail;

final system = createReactiveSystem(
      update: update,
      notify: notify,
      unwatched: unwatched,
    ),
    link = system.link,
    unlink = system.unlink,
    propagate = system.propagate,
    checkDirty = system.checkDirty,
    shallowPropagate = system.shallowPropagate;

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
bool update(ReactiveNode node) {
  if (node.depsTail != null) {
    return updateComputed(node as ComputedNode);
  } else {
    return updateSignal(node as SignalNode);
  }
}

void notify(ReactiveNode effect) {
  effect.flags &= ~ReactiveFlags.watching;
  final sub = effect.subs?.sub;
  if (sub != null &&
      (sub.flags & ReactiveFlags.watching) != ReactiveFlags.none) {
    notify(sub);
  }

  (effect as LinkedEffect).nextEffect = null;
  if (queuedEffectsTail == null) {
    queuedEffects = queuedEffectsTail = effect;
  } else {
    queuedEffectsTail!.nextEffect = effect;
    queuedEffects = effect;
  }

  // int insertIndex = queuedLength;
  // int firstInsertedIndex = insertIndex;

  // do {
  //   effect.flags &= ~ReactiveFlags.watching;
  //   queued.safeSet(insertIndex++, effect as EffectNode);
  //   final next = effect.subs?.sub;
  //   if (next == null ||
  //       ((effect = next).flags & ReactiveFlags.watching) ==
  //           ReactiveFlags.none) {
  //     break;
  //   }
  // } while (true);

  // queuedLength = insertIndex;

  // while (firstInsertedIndex < --insertIndex) {
  //   final left = queued[firstInsertedIndex];
  //   queued[firstInsertedIndex++] = queued[insertIndex];
  //   queued[insertIndex] = left;
  // }
}

void unwatched(ReactiveNode node) {
  if ((node.flags & ReactiveFlags.mutable) == ReactiveFlags.none) {
    effectScopeOper(node);
  } else if (node.depsTail != null) {
    node.depsTail = null;
    node.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
    purgeDeps(node);
  }
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
ReactiveNode? getActiveSub() => activeSub;

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
ReactiveNode? setActiveSub([ReactiveNode? sub]) {
  final prevSub = activeSub;
  activeSub = sub;
  return prevSub;
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
int getBatchDepth() => batchDepth;

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
void startBatch() => ++batchDepth;

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
void endBatch() {
  if ((--batchDepth) == 0) flush();
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
T Function([T? newValue, bool nulls]) signal<T>(T initialValue) {
  final s = SignalNode(
      currentValue: initialValue,
      pendingValue: initialValue,
      flags: ReactiveFlags.mutable);
  return ([value, nulls = false]) => signalOper(s, value, nulls);
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
T Function() computed<T>(T Function(T?) getter) {
  final c = ComputedNode(
    getter: getter,
    flags: ReactiveFlags.none,
  );
  return () => computedOper(c);
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
void Function() effect(void Function() fn) {
  final e = EffectNode(
    fn: fn,
    flags: ReactiveFlags.watching | ReactiveFlags.recursedCheck,
  );
  final prevSub = setActiveSub(e);
  if (prevSub != null) {
    link(e, prevSub, 0);
  }
  try {
    e.fn();
  } finally {
    activeSub = prevSub;
    e.flags &= ~ReactiveFlags.recursedCheck;
  }
  return () => effectOper(e);
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
void Function() effectScope(void Function() fn) {
  final e = ReactiveNode(flags: ReactiveFlags.none);
  final prevSub = setActiveSub(e);
  if (prevSub != null) {
    link(e, prevSub, 0);
  }
  try {
    fn();
  } finally {
    activeSub = prevSub;
  }
  return () => effectScopeOper(e);
}

void trigger(void Function() fn) {
  final sub = ReactiveNode(flags: ReactiveFlags.watching),
      prevSub = setActiveSub(sub);
  try {
    fn();
  } finally {
    activeSub = prevSub;
    while (sub.deps != null) {
      final link = sub.deps!, dep = link.dep;
      unlink(link, sub);
      final subs = dep.subs;
      if (subs != null) {
        propagate(subs);
        shallowPropagate(subs);
      }
    }
    if (batchDepth == 0) flush();
  }
}

bool updateComputed<T>(ComputedNode<T> c) {
  ++cycle;
  c.depsTail = null;
  c.flags = ReactiveFlags.mutable | ReactiveFlags.recursedCheck;
  final prevSub = setActiveSub(c);
  try {
    return c.run();
  } finally {
    activeSub = prevSub;
    c.flags &= ~ReactiveFlags.recursedCheck;
    purgeDeps(c);
  }
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
bool updateSignal<T>(SignalNode<T> s) {
  s.flags = ReactiveFlags.mutable;
  return s.currentValue != (s.currentValue = s.pendingValue);
}

void run(EffectNode e) {
  final flags = e.flags;
  if ((flags & ReactiveFlags.dirty) != ReactiveFlags.none ||
      ((flags & ReactiveFlags.pending) != ReactiveFlags.none &&
          checkDirty(e.deps!, e))) {
    ++cycle;
    e.depsTail = null;
    e.flags = ReactiveFlags.watching | ReactiveFlags.recursedCheck;
    final prevSub = setActiveSub(e);
    try {
      e.fn();
    } finally {
      activeSub = prevSub;
      e.flags &= ~ReactiveFlags.recursedCheck;
      purgeDeps(e);
    }
  } else {
    e.flags = ReactiveFlags.watching;
  }
}

void flush() {
  while (queuedEffects != null) {
    final effect = queuedEffects!;
    if ((queuedEffects = effect.nextEffect) != null) {
      effect.nextEffect = null;
    } else {
      queuedEffectsTail = null;
    }
    run(effect as EffectNode);
  }

  // while (notifyIndex < queuedLength) {
  //   final effect = queued[notifyIndex]!;
  //   queued[notifyIndex++] = null;
  //   run(effect);
  // }
  // notifyIndex = 0;
  // queuedLength = 0;
}

T computedOper<T>(ComputedNode<T> c) {
  final flags = c.flags;
  if ((flags & ReactiveFlags.dirty) != ReactiveFlags.none ||
      ((flags & ReactiveFlags.pending) != ReactiveFlags.none &&
          (checkDirty(c.deps!, c) ||
              identical(c.flags = flags & ~ReactiveFlags.pending, false)))) {
    if (updateComputed(c)) {
      final subs = c.subs;
      if (subs != null) {
        shallowPropagate(subs);
      }
    }
  } else if (flags == ReactiveFlags.none) {
    c.flags = ReactiveFlags.mutable | ReactiveFlags.recursedCheck;
    final prevSub = setActiveSub(c);
    try {
      c.value = c.getter(null);
    } finally {
      activeSub = prevSub;
      c.flags &= ~ReactiveFlags.recursedCheck;
    }
  }

  final sub = activeSub;
  if (sub != null) {
    link(c, sub, cycle);
  }

  return c.value as T;
}

T signalOper<T>(SignalNode<T> s, T? newValue, bool nulls) {
  if (newValue != null || nulls) {
    if (s.pendingValue != (s.pendingValue = newValue as T)) {
      s.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
      final subs = s.subs;
      if (subs != null) {
        propagate(subs);
        if (batchDepth == 0) flush();
      }
    }

    return newValue;
  } else {
    if ((s.flags & ReactiveFlags.dirty) != ReactiveFlags.none) {
      if (updateSignal(s)) {
        final subs = s.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    }
    ReactiveNode? sub = activeSub;
    while (sub != null) {
      if ((sub.flags & (ReactiveFlags.mutable | ReactiveFlags.watching)) !=
          ReactiveFlags.none) {
        link(s, sub, cycle);
        break;
      }
      sub = sub.subs?.sub;
    }
    return s.currentValue;
  }
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
void effectOper(EffectNode e) => effectScopeOper(e);

void effectScopeOper(ReactiveNode node) {
  node.depsTail = null;
  node.flags = ReactiveFlags.none;
  purgeDeps(node);
  final subs = node.subs;
  if (subs != null) {
    unlink(subs);
  }
}

void purgeDeps(ReactiveNode sub) {
  final depsTail = sub.depsTail;
  Link? dep = depsTail != null ? depsTail.nextDep : sub.deps;
  while (dep != null) {
    dep = unlink(dep, sub);
  }
}

// extension on List<EffectNode?> {
//   @pragma('vm:prefer-inline')
//   @pragma('dart2js:tryInline')
//   @pragma('wasm:prefer-inline')
//   void safeSet(int index, EffectNode? value) {
//     if (index >= length) length = index + 1;
//     this[index] = value;
//   }
// }
