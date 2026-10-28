import 'package:alien_signals/system.dart';

// #region system
// A manual graph that queues notifications for the caller to process.
class ManualSystem extends ReactiveSystem {
  final pending = <ReactiveNode>[];

  // This graph has no lazily computed values to update.
  @override
  bool update(ReactiveNode node) => false;

  @override
  void notify(ReactiveNode node) => pending.add(node);

  // These nodes own no external resources to release.
  @override
  void unwatched(ReactiveNode node) {}
}
// #endregion system

void main() {
  // #region graph
  final system = ManualSystem();
  final source = ReactiveNode(flags: .mutable);
  final watcher = ReactiveNode(flags: .watching);
  system.link(source, watcher, 0);

  system.propagate(source.subs!);
  system.propagate(source.subs!); // Already pending; no duplicate notification.
  print(system.pending.length); // 1
  assert(identical(system.pending.single, watcher)); // #hide

  // Process the queued work, then make the watcher ready for another change.
  for (final node in system.pending) {
    print(node.flags & ReactiveFlags.pending != ReactiveFlags.none); // true
    assert((node.flags & ReactiveFlags.pending) != .none); // #hide
    node.flags = .watching;
  }
  system.pending.clear();

  system.unlink(watcher.deps!, watcher);
  print(source.subs == null); // true; the graph is disconnected.
  assert(source.subs == null && watcher.deps == null); // #hide
  // #endregion graph
}
