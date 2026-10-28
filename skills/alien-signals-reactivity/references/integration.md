# Downstream integration

Read this when wrapping the public API, customizing preset nodes, or implementing
a reactive system. Use the consumer's resolved alien_signals version. Import
public libraries; reading implementation code to verify behavior does not make
hidden exports or private flags a supported extension protocol.

## Adapt the surface before building nodes

Delegate reads, writes, and disposal to the surface when its behavior already
fits. Keep one dependency graph and one value cache. An extension type can adapt
accessors without a wrapper allocation; use a class when it needs its own state
or runtime identity.

```dart
import 'package:alien_signals/alien_signals.dart' as alien;

extension type ValueSignal<T>._(alien.WritableSignal<T> _signal) {
  factory ValueSignal(T value) => ValueSignal._(alien.signal(value));

  T get value => _signal();
  set value(T next) => _signal.set(next);
}

extension type ValueComputed<T>._(alien.Computed<T> _computed) {
  factory ValueComputed(T Function() getter) =>
      ValueComputed._(alien.computed((_) => getter()));

  T get value => _computed();
}

void main() {
  final count = ValueSignal(0);
  final doubled = ValueComputed(() => count.value * 2);
  final seen = <int>[];
  final stop = alien.effect(() {
    seen.add(doubled.value);
  });

  count.value = 2;
  stop();
  count.value = 3;
  assert(seen.join(',') == '0,4');
  assert(doubled.value == 6);
}
```

An adapter's `dispose()` can delegate to the effect's callable stop handle.
Additional behavior such as cleanup registration, equality, or resource loading
is a separate contract: describe its semantics and verify it rather than silently
changing upstream behavior.

When documenting a downstream library, teach its own imports, public names, and
ownership rules. State any differences in equality, scheduling, or errors. Its
users should not need preset-node knowledge to use a surface wrapper. If the
task includes distributing a package skill, describe that public contract in a
skill named for the downstream package; dependency skills are discovered from
direct dependencies and do not replace the downstream library's guidance.

## Customize preset nodes with their lifecycle

Move here when concrete node access or node behavior is part of the requirement.
Changing `.call()` into `.value` alone is already handled by surface composition.

`SignalNode.get/set` and `ComputedNode.get` already implement tracking and updates.
They share the surface's runtime, so surface effects can observe node wrappers
and provide the complete effect lifecycle:

```dart
import 'package:alien_signals/alien_signals.dart' show effect;
import 'package:alien_signals/preset.dart';
import 'package:alien_signals/system.dart' show ReactiveFlags;

extension type NodeSignal<T>._(SignalNode<T> _node) {
  factory NodeSignal(T value) => NodeSignal._(
    SignalNode(
      flags: ReactiveFlags.mutable,
      currentValue: value,
      pendingValue: value,
    ),
  );

  T get value => _node.get();
  set value(T next) => _node.set(next);
}

extension type NodeComputed<T>._(ComputedNode<T> _node) {
  factory NodeComputed(T Function() getter) => NodeComputed._(
    ComputedNode(flags: ReactiveFlags.none, getter: (_) => getter()),
  );

  T get value => _node.get();
}

void main() {
  final count = NodeSignal(0);
  final doubled = NodeComputed(() => count.value * 2);
  final seen = <int>[];
  final stop = effect(() {
    seen.add(doubled.value);
  });

  count.value = 2;
  stop();
  count.value = 3;
  assert(seen.join(',') == '0,4');
  assert(doubled.value == 6);
}
```

Observe these boundaries when more customization is necessary:

- Constructing an `EffectNode` alone does not run or track its callback. Initial
  execution, nested ownership, cleanup capture, execution depth, dependency
  pruning, and exception-safe context restoration all belong to the lifecycle.
  Prefer the surface factory when that lifecycle fits.
- Preset tracking, batching, execution depth, and effect queue state are shared
  within the isolate. A new `PresetReactiveSystem` instance does not create an
  isolated runtime. Use the system layer if independent runtime policies are
  required; do not assume a Zone changes the preset's globals.
- Save the result of `setActiveSub(...)` and restore it in `finally`. Setting it
  to `null` disables the caller's tracking and nested ownership: effects and
  scopes created there are detached and need separate disposal. A computed read
  still tracks its own getter's dependencies. This boundary is synchronous.
- Overriding `ComputedNode.didUpdate()` can bypass cached-error recovery even
  when dependency pruning is preserved. Review the selected version's complete
  update contract before changing equality or evaluation behavior. Private error
  state cannot be maintained by copying only the successful update path.
- Use public link/unlink and lifecycle operations according to their contracts.
  Do not assume `stop(ReactiveNode)` is a universal full-disposal API: for plain
  signal/computed nodes in the current preset, it removes dependencies and only
  the first subscriber link. A downstream API that promises removal of every
  subscriber must define and test that additional behavior.

## Supply policies at the system layer

The system is a dependency graph and propagation engine. It does not supply
signal values, an active-subscriber context, effect callbacks, or a scheduler.
Decide those policies explicitly when building a different reactive model.

| Hook or operation | Responsibility |
| --- | --- |
| `update(node)` | Refresh the node and return whether its value changed |
| `notify(node)` | Process or schedule a notified watcher according to the chosen scheduling policy |
| `unwatched(node)` | Handle a dependency losing its last subscriber |
| `link(dep, sub, version)` | Record that `sub` depends on `dep` |
| `unlink(link, sub)` | Remove a dependency edge while maintaining both sides of the graph |
| `propagate(link)` | Mark affected subscribers and notify watching nodes |
| `checkDirty(link, sub)` | Resolve pending dependencies through `update` |

For dynamic tracking, coordinate versions, `depsTail`, and removal of dependencies
not read during the latest evaluation. Inspect the resolved preset's complete
evaluation/pruning flow as a reference. Writing graph fields independently can
leave stale or one-sided links.

This complete manual graph has no values, lazy computations, automatic tracking,
or external resources. It demonstrates notification and unlinking only:

```dart
import 'package:alien_signals/system.dart';

class ManualSystem extends ReactiveSystem {
  final pending = <ReactiveNode>[];

  @override
  bool update(ReactiveNode node) => false;

  @override
  void notify(ReactiveNode node) => pending.add(node);

  @override
  void unwatched(ReactiveNode node) {}
}

void main() {
  final system = ManualSystem();
  final source = ReactiveNode(flags: ReactiveFlags.mutable);
  final watcher = ReactiveNode(flags: ReactiveFlags.watching);
  system.link(source, watcher, 0);

  system.propagate(source.subs!);
  system.propagate(source.subs!);
  assert(system.pending.length == 1);
  assert(identical(system.pending.single, watcher));

  for (final node in system.pending) {
    assert((node.flags & ReactiveFlags.pending) != ReactiveFlags.none);
    node.flags = ReactiveFlags.watching;
  }
  system.pending.clear();

  system.unlink(watcher.deps!, watcher);
  assert(source.subs == null && watcher.deps == null);
}
```

An implementation with computed values needs a real `update` implementation;
resource-owning nodes need a meaningful `unwatched` policy. Identity comparison,
cached errors, and synchronous effects are preset choices, not requirements for
every system built on this graph.

## Verify the policy you changed

The built-in preset propagates effect/cleanup errors. A failed initial effect can
retain subscriptions without returning a stop handle. Cleanup from a throwing
callback is not installed because the callback did not return it. A cleanup
exception can interrupt disposal of remaining children. A batch body exception
leaves writes in place; `endBatch()` still flushes in `finally`.

Do not promise setup rollback, complete cleanup after an error, or automatic async
cancellation based solely on using an upstream effect or scope. If a downstream
contract requires these guarantees, design and test the policy at that boundary.

Match regression checks to the behavior being customized:

| Changed policy | Sequence that should distinguish a correct implementation |
| --- | --- |
| Dependency tracking | Switch a conditional branch, mutate the old dependency, and assert no obsolete notification |
| Computed evaluation or equality | Read twice, change a source without changing the derived result, then update a diamond graph; check values and evaluation counts |
| Batching or scheduling | Nest batches, stop a queued effect before flushing, and make a write inside an effect; check order and execution counts |
| Computed failure handling | Fail before and after a success, then recover; check the preserved previous value, including nullable results. For preset parity, invalidate and restore a source before the next read |
| Ownership or disposal | Stop a parent and assert child-before-parent cleanup; check cleanup failures and independently owned effects created after `await` or with tracking disabled |

Reuse the downstream test setup and assert observable results. Test intentional
policy differences against the downstream contract rather than forcing all custom
systems to reproduce preset behavior.
