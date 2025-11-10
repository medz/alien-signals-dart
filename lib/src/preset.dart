import 'package:alien_signals/system.dart';

int cycle = 0, batchDepth = 0;
ReactiveNode? activeSub;
LinkedEffect? queuedEffects;
LinkedEffect? queuedEffectsTail;

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
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

  void set(T newValue) {
    if (pendingValue != (pendingValue = newValue)) {
      flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
      final subs = this.subs;
      if (subs != null) {
        propagate(subs);
        if (batchDepth == 0) flush();
      }
    }
  }

  T get() {
    if ((flags & ReactiveFlags.dirty) != ReactiveFlags.none) {
      if (update()) {
        final subs = this.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    }
    ReactiveNode? sub = activeSub;
    while (sub != null) {
      if ((sub.flags & (ReactiveFlags.mutable | ReactiveFlags.watching)) !=
          ReactiveFlags.none) {
        link(this, sub, cycle);
        break;
      }
      sub = sub.subs?.sub;
    }
    return currentValue;
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  bool update() {
    flags = ReactiveFlags.mutable;
    return currentValue != (currentValue = pendingValue);
  }
}

class ComputedNode<T> extends ReactiveNode {
  final T Function(T?) getter;
  T? value;

  ComputedNode({required super.flags, required this.getter});

  T get() {
    final flags = this.flags;
    if ((flags & ReactiveFlags.dirty) != ReactiveFlags.none ||
        ((flags & ReactiveFlags.pending) != ReactiveFlags.none &&
            (checkDirty(deps!, this) ||
                identical(
                    this.flags = flags & ~ReactiveFlags.pending, false)))) {
      if (update()) {
        final subs = this.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    } else if (flags == ReactiveFlags.none) {
      this.flags = ReactiveFlags.mutable | ReactiveFlags.recursedCheck;
      final prevSub = setActiveSub(this);
      try {
        value = getter(null);
      } finally {
        activeSub = prevSub;
        this.flags &= ~ReactiveFlags.recursedCheck;
      }
    }

    final sub = activeSub;
    if (sub != null) {
      link(this, sub, cycle);
    }

    return value as T;
  }

  bool update() {
    ++cycle;
    depsTail = null;
    flags = ReactiveFlags.mutable | ReactiveFlags.recursedCheck;
    final prevSub = setActiveSub(this);
    try {
      return value != (value = getter(value));
    } finally {
      activeSub = prevSub;
      flags &= ~ReactiveFlags.recursedCheck;
      purgeDeps(this);
    }
  }
}

class EffectNode extends LinkedEffect {
  final void Function() fn;

  EffectNode({required super.flags, required this.fn});
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
@pragma('wasm:prefer-inline')
bool update(ReactiveNode node) {
  return switch (node) {
    ComputedNode() => node.update(),
    SignalNode() => node.update(),
    _ => false,
  };
}

void notify(ReactiveNode effect) {
  LinkedEffect? head;
  final LinkedEffect tail = effect as LinkedEffect;

  do {
    effect.flags &= ~ReactiveFlags.watching;
    (effect as LinkedEffect).nextEffect = head;
    head = effect;

    final next = effect.subs?.sub;
    if (next == null ||
        ((effect = next).flags & ReactiveFlags.watching) ==
            ReactiveFlags.none) {
      break;
    }
  } while (true);

  if (queuedEffectsTail == null) {
    queuedEffects = queuedEffectsTail = head;
  } else {
    queuedEffectsTail!.nextEffect = head;
    queuedEffectsTail = tail;
  }
}

void unwatched(ReactiveNode node) {
  if ((node.flags & ReactiveFlags.mutable) == ReactiveFlags.none) {
    stop(node);
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
  return () => stop(e);
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
  return () => stop(e);
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
}

void stop(ReactiveNode node) {
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
