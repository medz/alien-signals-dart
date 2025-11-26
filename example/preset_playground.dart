// ignore_for_file: camel_case_types

import 'package:alien_signals/preset.dart';
import 'package:alien_signals/system.dart';

extension type signal<T>._(SignalNode<T> _) {
  factory signal(T initialValue) {
    return signal._(SignalNode(
      flags: ReactiveFlags.mutable,
      currentValue: initialValue,
      pendingValue: initialValue,
    ));
  }

  T get value => _.get();
  set value(newValue) => _.set(newValue);
}

extension type computed<T>._(ComputedNode<T> _) {
  factory computed(T Function() getter) {
    return computed._(ComputedNode(
      getter: (_) => getter(),
      flags: ReactiveFlags.none,
    ));
  }

  T get value => _.get();
}

extension type effect._(EffectNode _) {
  factory effect(void Function() run) {
    final node = EffectNode(
        fn: run, flags: ReactiveFlags.watching | ReactiveFlags.recursedCheck);
    final prevSub = setActiveSub(node);
    if (prevSub != null) link(node, prevSub, 0);
    try {
      run();
      return effect._(node);
    } finally {
      activeSub = prevSub;
      node.flags &= ~ReactiveFlags.recursedCheck;
    }
  }

  void call() => stop(_);
}

void main() {
  final count = signal(0);
  final doubled = computed(() => count.value * 2);

  final stop = effect(() {
    print('Count: ${count.value}, Doubled: ${doubled.value}');
  });

  count.value = 2;
  stop();
  count.value = 3;
}
