# Alien Signals Guide

Alien Signals provides a reusable reactive engine, a signals preset, and a
small surface API. Choose the layer that matches your use case.

| Layer | Import | Use it for |
| --- | --- | --- |
| Surface | `package:alien_signals/alien_signals.dart` | Signals, computed values, and effects out of the box. |
| Preset | `package:alien_signals/preset.dart` | Custom value accessors with the existing signals semantics. |
| System | `package:alien_signals/system.dart` | Custom primitives, dependency tracking, or scheduling. |

See the [API reference](api.md) for links to each public library.

## Start with the surface API

Run the [basic example](../example/main.dart) from the package root:

```sh
dart run example/main.dart
```

It creates a writable signal, derives a computed value, observes both with an
effect, and stops the effect. Read a signal with `value()` and write it with
`value.set(next)`. Every effect created outside a managed scope needs a retained
disposal handle.

The [recipes](recipes.md) link to runnable examples for caching, cleanup,
scopes, batching, and manual notification.

## Customize the surface with preset nodes

The [preset playground](../example/preset_playground.dart) wraps `SignalNode`
and `ComputedNode` in extension types with `.value` accessors. It uses the
public surface `effect()` function for scheduling, cleanup, and nested effect
ownership. The wrappers and effects share the preset's dependency tracker.

```sh
dart run example/preset_playground.dart
```

Constructing an `EffectNode` alone does not start the effect or establish its
lifecycle. Reuse `effect()` when customizing value accessors; a custom effect
factory must also manage tracking, ownership, execution depth, and cleanup.
The implementation in [surface.dart](../lib/src/surface.dart) is the reference
for that lifecycle.

## Build on the system

The system combines push and pull propagation:

- Writes mark dependent nodes pending or dirty and notify watchers.
- Reads check dependencies and update derived values only when necessary.

The [manual graph example](../example/system.dart) links a source to a watcher,
queues a notification, processes it, and unlinks the nodes. It uses no preset
state and intentionally has no computed values or external resources.

```sh
dart run example/system.dart
```

To build full reactive primitives, store values in your own node types, track
the active subscriber, and link dependencies when they are read. Implement
`ReactiveSystem.update`, `notify`, and `unwatched` for recomputation, scheduling,
and resource cleanup. Use `checkDirty` for lazy reads. The
[preset implementation](../lib/src/preset.dart) is a complete example of this
contract.

## Value and lifecycle semantics

- Signal writes and computed results use `identical`, not `==`. Mutating a list
  or map in place requires `trigger(() => value())` to notify readers.
- Computed getters cache errors as well as values. Reads rethrow a cached error
  until a tracked dependency changes. Successful retries clear it; the getter
  receives its last successful value as the previous-value argument.
- Effects run immediately and track synchronous reads. Cleanup returned
  synchronously runs before the next execution and on stop, without tracking
  its reads. Nested effects and scopes stop before their parent's cleanup.
- Tracking and scope ownership do not continue across `await`. Read inputs
  before starting asynchronous work and retain disposal handles for effects
  created after an `await`.

## Maintain documentation and examples

Keep API examples in runnable `example/*.dart` files, using `package:` imports.
Mark reusable snippets with `// #region name` and `// #endregion name`, then
reference them on their own doc-comment line with
`{@example /example/file.dart#name}`. A line ending in `// #hide` can hold an
assertion or test-only setup. Keep each hidden statement on one line, since
Dartdoc removes whole lines and only filters markers when a region is selected.

Keep the first paragraph of an API comment to a short summary. Explain
parameters and lifecycle behavior in prose and link in-scope symbols with
square brackets. Follow the Dart team's
[documentation skill](https://github.com/dart-lang/skills/blob/main/skills/dart-write-documentation/SKILL.md)
and [example skill](https://github.com/dart-lang/skills/blob/main/skills/dart-use-doc-examples/SKILL.md).

GitHub and pub.dev Markdown pages do not expand `{@example}`. Keep one short
README introduction and link to runnable examples from the guides. Keep
`example/main.dart` as the package's pub.dev Example entrypoint.

Validate examples with assertions enabled and build the docs with Dartdoc
9.0.6 or later, which supports example regions:

```sh
dart analyze
dart test
for example in example/*.dart; do
  dart --enable-asserts run "$example"
done
dart doc --validate-links --output build/api
```

CI runs the same example and documentation checks once alongside analysis.
Missing example files, missing regions, invalid directive parameters, unresolved
API references, and broken generated links fail the documentation build.
Generated documentation belongs in the ignored `build/api` or `doc/api` directory.
