/// A node in a reactive system that tracks dependencies and subscribers.
///
/// The [ReactiveNode] maintains two linked lists:
/// - [deps]/[depsTail] tracks dependencies (nodes this node depends on)
/// - [subs]/[subsTail] tracks subscribers (nodes that depend on this node)
///
/// The [flags] property stores various state flags for the node.
abstract class ReactiveNode {
  /// Creates a new [ReactiveNode] with the given dependencies, subscribers, and flags.
  ///
  /// - [deps]: Head of the dependencies linked list (nodes this node depends on)
  /// - [depsTail]: Tail of the dependencies linked list
  /// - [subs]: Head of the subscribers linked list (nodes that depend on this node)
  /// - [subsTail]: Tail of the subscribers linked list
  /// - [flags]: Bit flags representing the node's state and properties
  ReactiveNode({
    this.deps,
    this.depsTail,
    this.subs,
    this.subsTail,
    required this.flags,
  });

  /// Head of the dependencies linked list (nodes this node depends on).
  Link? deps;

  /// Tail of the dependencies linked list.
  Link? depsTail;

  /// Head of the subscribers linked list (nodes that depend on this node).
  Link? subs;

  /// Tail of the subscribers linked list.
  Link? subsTail;

  /// Bit flags representing the node's state and properties.
  ReactiveFlags flags;
}

/// A link between a dependent node ([dep]) and a subscriber node ([sub]).
///
/// Links form doubly-linked lists in both directions:
/// - Through [prevSub]/[nextSub] for subscribers of a dependency
/// - Through [prevDep]/[nextDep] for dependencies of a subscriber
class Link {
  /// A bidirectional link between a dependency ([dep]) and subscriber ([sub]) node.
  ///
  /// Links form doubly-linked lists in both directions:
  /// - [prevSub]/[nextSub] form the subscriber list (nodes that depend on [dep])
  /// - [prevDep]/[nextDep] form the dependency list (nodes that [sub] depends on)
  Link({
    required this.dep,
    required this.sub,
    this.prevSub,
    this.nextSub,
    this.prevDep,
    this.nextDep,
  });

  /// The dependency node that [sub] depends on.
  ReactiveNode dep;

  /// The subscriber node that depends on [dep].
  ReactiveNode sub;

  /// Previous link in the subscriber list (nodes that depend on [dep]).
  Link? prevSub;

  /// Next link in the subscriber list (nodes that depend on [dep]).
  Link? nextSub;

  /// Previous link in the dependency list (nodes that [sub] depends on).
  Link? prevDep;

  /// Next link in the dependency list (nodes that [sub] depends on).
  Link? nextDep;
}

/// A simple stack data structure implemented as a linked list.
///
/// Each [Stack] node contains a [value] of type [T] and an optional reference
/// to the previous node ([prev]) in the stack. This creates a LIFO (Last-In-First-Out)
/// structure where the most recently added items are at the top of the stack.
///
/// Example:
/// ```dart
/// final stack = Stack<int>(value: 1);
/// stack.prev = Stack<int>(value: 2);
/// ```
final class Stack<T> {
  Stack({required this.value, this.prev});

  /// The value stored in this stack node.
  T value;

  /// The previous node in the stack, or `null` if this is the bottom node.
  Stack<T>? prev;
}

/// A set of bit flags representing various states and properties of a [ReactiveNode].
///
/// The flags are implemented as an extension type wrapping an [int] to provide
/// type-safe bit manipulation operations while maintaining the performance
/// characteristics of primitive integers.
extension type const ReactiveFlags._(int raw) implements int {
  /// No flags set.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static const none = ReactiveFlags._(0);

  /// Indicates the node's value can be changed directly.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static const mutable = ReactiveFlags._(1 << 0);

  /// Indicates the node is being watched for changes.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static const watching = ReactiveFlags._(1 << 1);

  /// Used during dependency tracking to check for recursion.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static const recursedCheck = ReactiveFlags._(1 << 2);

  /// Indicates the node is being recursively processed.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static const recursed = ReactiveFlags._(1 << 3);

  /// Indicates the node's value is out of date and needs recomputation.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static const dirty = ReactiveFlags._(1 << 4);

  /// Indicates the node has changes that need to be propagated.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static const pending = ReactiveFlags._(1 << 5);

  /// Bitwise AND operator for combining flags.
  ///
  /// Returns new [ReactiveFlags] with only the bits set that are present in both
  /// this flags and [other].
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  ReactiveFlags operator &(int other) => ReactiveFlags._(raw & other);

  /// Bitwise OR operator for combining flags.
  ///
  /// Returns new [ReactiveFlags] with bits set from either this flags or [other].
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  ReactiveFlags operator |(int other) => ReactiveFlags._(raw | other);
}

/// A reactive system base class.
abstract class ReactiveSystem {
  const ReactiveSystem();

  /// Updates the node's value if it's dirty and returns whether it was updated.
  ///
  /// Returns `true` if the node was dirty and its value was successfully updated,
  /// `false` otherwise.
  bool update(ReactiveNode sub);

  /// Notifies the system that the node has changed and needs to be processed.
  ///
  /// This is called when a node's value changes and it needs to notify its
  /// subscribers about the change.
  void notify(ReactiveNode sub);

  /// Called when a node no longer has any subscribers watching it.
  ///
  /// This allows the system to perform cleanup for nodes that are no longer
  /// being observed.
  void unwatched(ReactiveNode sub);

  /// Creates a bidirectional link between a dependency node ([dep]) and a subscriber node ([sub]).
  ///
  /// This establishes the relationship where:
  /// - [sub] depends on [dep] (added to [sub]'s dependency list)
  /// - [dep] has [sub] as a subscriber (added to [dep]'s subscriber list)
  ///
  /// The method handles various edge cases including:
  /// - Avoiding duplicate links
  /// - Maintaining proper list structure during recursive checks
  /// - Preserving existing valid links
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
    final newLink = sub.depsTail = dep.subsTail = Link(
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

  /// Removes a bidirectional link between a dependency node and subscriber node.
  ///
  /// This method:
  /// - Removes the [link] from both the subscriber's dependency list and the
  ///   dependency's subscriber list
  /// - Optionally accepts a [sub] node to specify which subscriber to unlink from
  /// - Returns the next dependency link in the subscriber's list (if any)
  ///
  /// The unlinking process handles:
  /// - Updating adjacent links to maintain proper list structure
  /// - Cleaning up empty subscriber lists by calling [unwatched]
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

  /// Propagates changes through the reactive graph starting from the given [link].
  ///
  /// This method:
  /// - Processes subscribers in depth-first order using a stack
  /// - Handles various node states (mutable, watching, dirty, pending)
  /// - Manages recursive checks and propagation flags
  /// - Notifies watchers when changes occur
  void propagate(Link link) {
    var next = link.nextSub;
    Stack<Link?>? stack;

    top:
    do {
      final sub = link.sub;

      var flags = sub.flags;

      if (flags & 3 /* ReactiveFlags.mutable | ReactiveFlags.watching */ != 0) {
        if ((flags &
                60 /* ReactiveFlags.recursedCheck | ReactiveFlags.recursed | ReactiveFlags.dirty | ReactiveFlags.pending */) ==
            0) {
          sub.flags = flags | ReactiveFlags.pending;
        } else if ((flags &
                12 /* ReactiveFlags.recursedCheck | ReactiveFlags.recursed */) ==
            0) {
          flags = ReactiveFlags.none;
        } else if ((flags & ReactiveFlags.recursedCheck) == 0) {
          sub.flags = (flags & -9 /* ~ReactiveFlags.recursed */) |
              ReactiveFlags.pending;
        } else if ((flags &
                    48 /* ReactiveFlags.dirty | ReactiveFlags.pending */) ==
                0 &&
            isValidLink(link, sub)) {
          sub.flags =
              flags | 40 /* ReactiveFlags.recursed | ReactiveFlags.pending */;
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

  /// Starts tracking dependencies for the given [sub] node.
  ///
  /// This method:
  /// - Resets the dependency tracking state by clearing [depsTail]
  /// - Updates the node's flags to:
  ///   - Clear any recursive/dirty/pending flags
  ///   - Set the [ReactiveFlags.recursedCheck] flag to indicate dependency tracking is active
  void startTracking(ReactiveNode sub) {
    sub.depsTail = null;
    sub.flags = (sub.flags &
            -57 /* ~(ReactiveFlags.recursed | ReactiveFlags.dirty | ReactiveFlags.pending) */) |
        ReactiveFlags.recursedCheck;
  }

  /// Completes dependency tracking for the given [sub] node.
  ///
  /// This method:
  /// - Removes any dependencies that were not tracked during this cycle
  /// - Clears the [ReactiveFlags.recursedCheck] flag to indicate tracking is complete
  void endTracking(ReactiveNode sub) {
    final depsTail = sub.depsTail;
    var toRemove = depsTail != null ? depsTail.nextDep : sub.deps;
    while (toRemove != null) {
      toRemove = unlink(toRemove, sub);
    }
    sub.flags &= -5 /* ~ReactiveFlags.recursedCheck */;
  }

  /// Checks if a node or any of its dependencies are dirty and need updating.
  ///
  /// This method:
  /// - Traverses the dependency graph starting from [checkLink]
  /// - Checks if [sub] or any of its dependencies are dirty ([ReactiveFlags.dirty])
  /// - Updates nodes as needed during the traversal
  /// - Returns `true` if any dirty nodes were found, `false` otherwise
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
      } else if ((depFlags &
              17 /* ReactiveFlags.mutable | ReactiveFlags.dirty */) ==
          17 /* ReactiveFlags.mutable | ReactiveFlags.dirty */) {
        if (update(dep)) {
          final subs = dep.subs;
          if (subs?.nextSub != null) {
            shallowPropagate(subs!);
          }
          dirty = true;
        }
      } else if ((depFlags &
              33 /* ReactiveFlags.mutable | ReactiveFlags.pending */) ==
          33 /* ReactiveFlags.mutable | ReactiveFlags.pending */) {
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
          sub.flags &= -33 /* ~ReactiveFlags.pending */;
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

  /// Propagates changes shallowly through the reactive graph starting from [link].
  ///
  /// Unlike [propagate], this method only processes immediate subscribers without
  /// traversing deeper into the dependency graph. It marks subscribers as dirty
  /// if they are pending and notifies watchers when changes occur.
  void shallowPropagate(Link link) {
    Link? current = link;
    do {
      final sub = current!.sub;
      final nextSub = current.nextSub;
      final subFlags = sub.flags;
      if ((subFlags & 48 /* ReactiveFlags.pending | ReactiveFlags.dirty */) ==
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
