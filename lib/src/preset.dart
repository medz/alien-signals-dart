import 'surface.dart';
import 'system.dart';

int cycle = 0, batchDepth = 0, notifyIndex = 0, queuedLength = 0;
ReactiveNode? activeSub;

final queued = <int, PresetEffect?>{};
const ReactiveSystem system = _PresetReactiveSystem();
final link = system.link,
    unlink = system.unlink,
    propagate = system.propagate,
    checkDirty = system.checkDirty,
    shallowPropagate = system.shallowPropagate;

class _PresetReactiveSystem extends ReactiveSystem {
  const _PresetReactiveSystem();

  @override
  void notify(ReactiveNode sub) {
    int insertIndex = queuedLength, firstInsertedIndex = insertIndex;
    do {
      sub.flags &= -3 /* ~Watching */;
      queued[insertIndex++] = sub as PresetEffect;
      final subsSub = sub.subs?.sub;
      if (subsSub == null || (subsSub.flags & 2 /* Watching */) == 0) {
        break;
      }

      sub = subsSub;
    } while (true);

    queuedLength = insertIndex;

    while (firstInsertedIndex < --insertIndex) {
      final left = queued[firstInsertedIndex];
      queued[firstInsertedIndex++] = queued[insertIndex];
      queued[insertIndex] = left;
    }
  }

  @override
  void unwatched(ReactiveNode sub) {
    if ((sub.flags & 1 /* Mutable */) == 0) {
      effectScopeOper(sub);
    } else if (sub.depsTail != null) {
      sub.depsTail = null;
      sub.flags = 17 /* Mutable | Dirty */;
      purgeDeps(sub);
    }
  }

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool update(ReactiveNode sub) {
    return switch (sub) {
      PresetSignal(:final shouldUpdate) => shouldUpdate(),
      PresetComputed(:final shouldUpdate) => shouldUpdate(),
      _ => false,
    };
  }
}

class PresetSignal<T> extends ReactiveNode implements Signal<T> {
  PresetSignal({super.flags = 1 /* Mutable */, required T initialValue})
      : currentValue = initialValue,
        pendingValue = initialValue;

  T currentValue;
  T pendingValue;

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T call([T Function()? updates]) => signalOper(this, updates);

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool shouldUpdate() => updateSignal(this);
}

class PresetComputed<T> extends ReactiveNode implements Computed<T> {
  PresetComputed({super.flags = 0 /* None */, required this.getter});

  T? value;
  final T Function(T? previousValue) getter;

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T call() => computedOper(this);

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool shouldUpdate() => updateComputed(this);
}

class PresetEffect extends ReactiveNode implements Effect {
  PresetEffect({super.flags = 2 /* Watching */, required this.fn});

  final void Function() fn;

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void call() => effectOper(this);
}

class PresetEffectScope extends ReactiveNode implements EffectScope {
  PresetEffectScope({super.flags = 0 /* None */});

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void call() => effectScopeOper(this);
}

bool updateComputed<T>(PresetComputed<T> computed) {
  ++cycle;
  computed.depsTail = null;
  computed.flags = 5 /* Mutable | RecursedCheck */;
  final prevSub = setActiveSub(computed);
  try {
    final oldValue = computed.value;
    return oldValue != (computed.value = computed.getter(oldValue));
  } finally {
    activeSub = prevSub;
    computed.flags &= -5 /* ~RecursedCheck */;
    purgeDeps(computed);
  }
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
bool updateSignal<T>(PresetSignal<T> signal) {
  signal.flags = 1 /* Mutable */;
  return signal.currentValue != (signal.currentValue = signal.pendingValue);
}

void run(PresetEffect effect) {
  final flags = effect.flags;
  if ((flags & 16 /* Dirty */) != 0 ||
      ((flags & 32 /* Pending */) != 0 &&
          checkDirty(effect.deps as Link, effect))) {
    ++cycle;
    effect.depsTail = null;
    effect.flags = 6 /* Watching | RecursedCheck */;
    final prevSub = setActiveSub(effect);
    try {
      effect.fn();
    } finally {
      activeSub = prevSub;
      effect.flags &= -5 /* RecursedCheck */;
      purgeDeps(effect);
    }
  } else {
    effect.flags = 2 /* Watching */;
  }
}

void flush() {
  while (notifyIndex < queuedLength) {
    final effect = queued[notifyIndex] as PresetEffect;
    queued[notifyIndex++] = null;
    run(effect);
  }
  notifyIndex = 0;
  queuedLength = 0;
}

T computedOper<T>(PresetComputed<T> computed) {
  final flags = computed.flags;
  if ((flags & 16 /* Dirty */) != 0 ||
      ((flags & 32 /* Pending */) != 0 &&
          (checkDirty(computed.deps as Link, computed) ||
              (computed.flags = flags & -33 /* ~Pending */) ==
                  double.infinity))) {
    if (updateComputed(computed)) {
      final subs = computed.subs;
      if (subs != null) shallowPropagate(subs);
    }
  } else if (flags == 0 /* None */) {
    computed.flags = 1 /* Mutable */;
    final prevSub = setActiveSub(computed);
    try {
      computed.value = computed.getter(null);
    } finally {
      activeSub = prevSub;
    }
  }
  final sub = activeSub;
  if (sub != null) link(computed, sub, cycle);
  return computed.value as T;
}

T signalOper<T>(PresetSignal<T> signal, T Function()? updates) {
  if (updates != null) {
    final prevSub = setActiveSub(null), oldValue = signal.pendingValue;
    try {
      signal.pendingValue = updates();
    } finally {
      activeSub = prevSub;
    }

    if (oldValue != signal.pendingValue) {
      signal.flags = 17 /* Mutable | Dirty */;
      final subs = signal.subs;
      if (subs != null) {
        propagate(subs);
        if (batchDepth == 0) flush();
      }
    }

    return signal.pendingValue;
  } else {
    if ((signal.flags & 16 /* Dirty */) != 0) {
      if (updateSignal(signal)) {
        final subs = signal.subs;
        if (subs != null) shallowPropagate(subs);
      }
    }
    ReactiveNode? sub = activeSub;
    while (sub != null) {
      if ((sub.flags & 3 /* Mutable | Watching */) != 0) {
        link(signal, sub, cycle);
        break;
      }
      sub = sub.subs?.sub;
    }
    return signal.currentValue;
  }
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void effectOper(ReactiveNode node) => effectScopeOper(node);

void effectScopeOper(ReactiveNode node) {
  node.depsTail = null;
  node.flags = 0 /* None */;
  purgeDeps(node);
  final sub = node.subs;
  if (sub != null) unlink(sub);
}

void purgeDeps(ReactiveNode sub) {
  final depsTail = sub.depsTail;
  Link? dep = depsTail != null ? depsTail.nextDep : sub.deps;
  while (dep != null) {
    dep = unlink(dep, sub);
  }
}
