/// Bit flags that represent the state of reactive nodes in the system.
///
/// These flags are used to track various states and behaviors of reactive
/// nodes during the dependency tracking and update propagation process.
/// Multiple flags can be combined using bitwise operations.
///
/// The flags are designed to be efficient and allow for quick state checks
/// using bitwise operations.
extension type const ReactiveFlags._(int _) implements int {
  /// No flags set. The default state.
  static const none = 0 as ReactiveFlags;

  /// Indicates that this node is mutable (can be written to).
  /// Typically set for signals but not for computed values.
  static const mutable = 1 as ReactiveFlags;

  /// Indicates that this node is actively watching its dependencies.
  /// When set, the node will be notified of dependency changes.
  static const watching = 2 as ReactiveFlags;

  /// Used during recursion checking to detect circular dependencies.
  /// Temporarily set while checking for recursion.
  static const recursedCheck = 4 as ReactiveFlags;

  /// Indicates that this node has been visited during recursion detection.
  /// Helps prevent infinite loops in circular dependency scenarios.
  static const recursed = 8 as ReactiveFlags;

  /// Indicates that this node's value is outdated and needs recomputation.
  /// Set when dependencies change and cleared after successful update.
  static const dirty = 16 as ReactiveFlags;

  /// Indicates that this node has pending updates to process.
  /// Used during batch updates to mark nodes that need processing.
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

/// Base class for all reactive nodes in the dependency tracking system.
///
/// A ReactiveNode represents any value that can participate in the reactive
/// dependency graph. This includes signals, computed values, and effects.
///
/// Each node maintains two sets of connections:
/// - Dependencies (deps): Other nodes that this node depends on
/// - Subscribers (subs): Other nodes that depend on this node
///
/// The dependency tracking system uses doubly-linked lists to efficiently
/// manage these relationships, allowing for O(1) insertion and removal.
///
/// Example node types that extend ReactiveNode:
/// - SignalNode: Holds a mutable value
/// - ComputedNode: Derives its value from other nodes
/// - EffectNode: Runs side effects when dependencies change
class ReactiveNode {
  /// Bit flags representing the current state of this node.
  /// See [ReactiveFlags] for possible values.
  ReactiveFlags flags;

  /// Head of the linked list of dependencies (nodes this node depends on).
  /// Null if this node has no dependencies.
  Link? deps;

  /// Tail of the linked list of dependencies for O(1) append operations.
  /// Points to the last dependency link.
  Link? depsTail;

  /// Head of the linked list of subscribers (nodes that depend on this node).
  /// Null if no other nodes depend on this one.
  Link? subs;

  /// Tail of the linked list of subscribers for O(1) append operations.
  /// Points to the last subscriber link.
  Link? subsTail;

  ReactiveNode({
    required this.flags,
    this.deps,
    this.depsTail,
    this.subs,
    this.subsTail,
  });
}

/// Represents a dependency relationship between two reactive nodes.
///
/// A Link connects a dependency (dep) to a subscriber (sub), forming an edge
/// in the reactive dependency graph. Each link is part of two doubly-linked
/// lists:
/// - The dependency list of the subscriber node
/// - The subscriber list of the dependency node
///
/// This dual-list structure allows for efficient traversal and modification
/// of the dependency graph from both directions.
///
/// The version tracking ensures that stale dependencies are properly updated
/// or removed during reactive computations.
final class Link {
  /// Version number for tracking staleness of this dependency relationship.
  /// Used to determine if the link is still valid or needs updating.
  int version;

  /// The dependency node (the node being depended upon).
  /// This is the source of data that the subscriber reads from.
  ReactiveNode dep;

  /// The subscriber node (the node that depends on dep).
  /// This node will be notified when dep changes.
  ReactiveNode sub;

  /// Previous link in the subscriber list of the dependency node.
  /// Used for traversing all subscribers of a dependency.
  Link? prevSub;

  /// Next link in the subscriber list of the dependency node.
  /// Used for traversing all subscribers of a dependency.
  Link? nextSub;

  /// Previous link in the dependency list of the subscriber node.
  /// Used for traversing all dependencies of a subscriber.
  Link? prevDep;

  /// Next link in the dependency list of the subscriber node.
  /// Used for traversing all dependencies of a subscriber.
  Link? nextDep;

  Link({
    required this.version,
    required this.dep,
    required this.sub,
    this.prevSub,
    this.nextSub,
    this.prevDep,
    this.nextDep,
  });
}

final class Stack<T> {
  T value;
  Stack<T>? prev;

  Stack({required this.value, this.prev});
}

/// Abstract base class for implementing a reactive system.
///
/// The ReactiveSystem manages the core operations for maintaining a reactive
/// dependency graph, including linking nodes, propagating changes, and
/// checking for updates.
///
/// This class provides the fundamental infrastructure for reactive state
/// management, using a push-pull hybrid approach:
/// - **Push phase**: Changes propagate through the graph to mark affected nodes
/// - **Pull phase**: Values are lazily computed only when accessed
///
/// ## Implementation Requirements
///
/// Subclasses must implement three key methods:
/// - [update]: Updates a node's value and returns whether it changed
/// - [notify]: Schedules a node for processing (e.g., queuing an effect)
/// - [unwatched]: Handles cleanup when a node loses all subscribers
///
/// ## Provided Operations
///
/// The class provides complete implementations of:
/// - [link]: Establishes dependency relationships between nodes
/// - [unlink]: Removes dependency relationships
/// - [propagate]: Recursively propagates changes through the graph
/// - [shallowPropagate]: Propagates changes to immediate subscribers only
/// - [checkDirty]: Determines if a node needs updating
/// - [isValidLink]: Validates link integrity
///
/// ## Example Implementation
///
/// ```dart
/// class MyReactiveSystem extends ReactiveSystem {
///   @override
///   bool update(ReactiveNode node) {
///     // Update node value, return true if changed
///     return node.updateValue();
///   }
///
///   @override
///   void notify(ReactiveNode node) {
///     // Queue node for processing
///     queueEffect(node);
///   }
///
///   @override
///   void unwatched(ReactiveNode node) {
///     // Clean up node when no longer watched
///     node.cleanup();
///   }
/// }
/// ```
abstract class ReactiveSystem {
  const ReactiveSystem();

  /// Updates a reactive node's value.
  ///
  /// This method should recompute the node's value if necessary and
  /// return `true` if the value changed, `false` otherwise.
  ///
  /// Typically called during dependency checking and propagation to
  /// ensure nodes have current values.
  bool update(ReactiveNode node);

  /// Notifies that a reactive node needs processing.
  ///
  /// This method is called when a node (typically an effect) needs to
  /// be scheduled for execution. The implementation should queue the
  /// node for later processing or execute it immediately depending on
  /// the system's batching strategy.
  void notify(ReactiveNode node);

  /// Handles cleanup when a node loses all subscribers.
  ///
  /// Called when a dependency node no longer has any nodes depending on it.
  /// This is an opportunity to perform cleanup, stop computations, or
  /// release resources associated with the unwatched node.
  void unwatched(ReactiveNode node);

  /// Creates or updates a dependency link between two nodes.
  ///
  /// Establishes that [sub] depends on [dep], creating a bidirectional
  /// link in the dependency graph. The [version] parameter tracks the
  /// freshness of this dependency relationship.
  ///
  /// This method efficiently handles:
  /// - Deduplication: Avoids creating duplicate links
  /// - Version updates: Updates existing links with new versions
  /// - Reordering: Moves accessed dependencies to the tail for optimization
  ///
  /// The implementation maintains two doubly-linked lists:
  /// - deps/depsTail on the subscriber for its dependencies
  /// - subs/subsTail on the dependency for its subscribers
  void link(final ReactiveNode dep, final ReactiveNode sub, final int version) {
    final prevDep = sub.depsTail;
    if (prevDep != null && identical(prevDep.dep, dep)) {
      return;
    }
    final nextDep = prevDep != null ? prevDep.nextDep : sub.deps;
    if (nextDep != null && identical(nextDep.dep, dep)) {
      nextDep.version = version;
      sub.depsTail = nextDep;
      return;
    }
    final prevSub = dep.subsTail;
    if (prevSub != null &&
        prevSub.version == version &&
        identical(prevSub.sub, sub)) {
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

  /// Removes a dependency link from the graph.
  ///
  /// Disconnects the relationship represented by [link], removing it from
  /// both the dependency's subscriber list and the subscriber's dependency list.
  ///
  /// If the dependency node has no remaining subscribers after unlinking,
  /// [unwatched] is called to handle cleanup.
  ///
  /// Returns the next link in the subscriber's dependency list, or `null`
  /// if this was the last dependency.
  Link? unlink(final Link link, final ReactiveNode sub) {
    final dep = link.dep,
        prevDep = link.prevDep,
        nextDep = link.nextDep,
        nextSub = link.nextSub,
        prevSub = link.prevSub;
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

  /// Propagates changes recursively through the dependency graph.
  ///
  /// Starting from [link], traverses the graph depth-first to mark all
  /// affected nodes as dirty or pending. Handles circular dependencies
  /// and recursion detection.
  ///
  /// This method:
  /// - Marks dependent nodes as pending or dirty
  /// - Notifies watching effects for scheduling
  /// - Recursively propagates through mutable nodes
  /// - Uses an explicit stack to avoid call stack overflow
  ///
  /// The propagation stops at non-mutable nodes (like effects) or when
  /// circular dependencies are detected.
  @pragma('vm:align-loops')
  void propagate(Link link) {
    Link? next = link.nextSub;
    Stack<Link?>? stack;

    top:
    do {
      final sub = link.sub;
      ReactiveFlags flags = sub.flags;

      if ((flags &
              60 /*ReactiveFlags.recursedCheck | ReactiveFlags.recursed | ReactiveFlags.dirty | ReactiveFlags.pending*/
          ) ==
          ReactiveFlags.none) {
        sub.flags = flags | ReactiveFlags.pending;
      } else if ((flags &
              12 /*ReactiveFlags.recursedCheck | ReactiveFlags.recursed*/) ==
          ReactiveFlags.none) {
        flags = ReactiveFlags.none;
      } else if ((flags & ReactiveFlags.recursedCheck) == ReactiveFlags.none) {
        sub.flags =
            (flags & -9 /*~ReactiveFlags.recursed*/) | ReactiveFlags.pending;
      } else if ((flags & 48 /*ReactiveFlags.dirty | ReactiveFlags.pending*/) ==
              ReactiveFlags.none &&
          isValidLink(link, sub)) {
        sub.flags =
            flags | 40 /*(ReactiveFlags.recursed | ReactiveFlags.pending)*/;
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

  /// Propagates changes to immediate subscribers only.
  ///
  /// Unlike [propagate], this method only marks direct subscribers as dirty
  /// without recursive traversal. Used when a node's value has been confirmed
  /// to change and all immediate dependents need notification.
  ///
  /// Typically called after successful updates to notify immediate subscribers
  /// that their dependency has changed.
  @pragma('vm:align-loops')
  void shallowPropagate(Link link) {
    Link? curr = link;
    do {
      final sub = curr!.sub, flags = sub.flags;
      if ((flags & 48 /*(ReactiveFlags.pending | ReactiveFlags.dirty)*/) ==
          ReactiveFlags.pending) {
        sub.flags = flags | ReactiveFlags.dirty;
        if ((flags &
                6 /*(ReactiveFlags.watching | ReactiveFlags.recursedCheck)*/) ==
            ReactiveFlags.watching) {
          notify(sub);
        }
      }
    } while ((curr = curr.nextSub) != null);
  }

  /// Checks if a node is dirty by examining its dependencies.
  ///
  /// Traverses [sub]'s dependencies starting from [link] to determine if
  /// any have changed. If a dependency is dirty or pending, recursively
  /// checks its dependencies.
  ///
  /// This pull-based checking ensures values are only recomputed when
  /// actually needed, avoiding unnecessary calculations.
  ///
  /// Returns `true` if any dependency has changed, requiring [sub] to update,
  /// or `false` if all dependencies are clean.
  @pragma('vm:align-loops')
  bool checkDirty(Link link, ReactiveNode sub) {
    Stack<Link>? stack;
    int checkDepth = 0;
    bool dirty = false;

    top:
    do {
      final dep = link.dep, flags = dep.flags;

      if ((sub.flags & ReactiveFlags.dirty) != ReactiveFlags.none) {
        dirty = true;
      } else if ((flags &
              17 /*(ReactiveFlags.mutable | ReactiveFlags.dirty)*/) ==
          17 /*(ReactiveFlags.mutable | ReactiveFlags.dirty)*/) {
        if (update(dep)) {
          final subs = dep.subs!;
          if (subs.nextSub != null) {
            shallowPropagate(subs);
          }
          dirty = true;
        }
      } else if ((flags &
              33 /*(ReactiveFlags.mutable | ReactiveFlags.pending)*/) ==
          33 /*(ReactiveFlags.mutable | ReactiveFlags.pending)*/) {
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
        final firstSub = sub.subs!, hasMultipleSubs = firstSub.nextSub != null;

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
          sub.flags &= -33 /*~ReactiveFlags.pending*/;
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

  /// Validates that a link belongs to a node's dependency list.
  ///
  /// Checks if [checkLink] is present in [sub]'s dependency chain.
  /// Used during propagation to ensure link integrity and detect
  /// stale references.
  ///
  /// Returns `true` if the link is valid, `false` otherwise.
  @pragma('vm:align-loops')
  bool isValidLink(final Link checkLink, final ReactiveNode sub) {
    Link? link = sub.depsTail;
    while (link != null) {
      if (identical(link, checkLink)) return true;
      link = link.prevDep;
    }
    return false;
  }
}
