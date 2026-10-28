---
name: alien-signals-reactivity
description: >-
  Implement or debug reactive code that directly uses alien_signals, or build a
  downstream reactive library on its surface, preset, or system APIs. Guides
  layer selection, dependency tracking, lifecycle, batching, and error behavior.
---

# Alien Signals

## Choose the integration layer

Check the code's imports and resolved package version first. Preserve the public
API of an existing downstream library: its `.value` or `.dispose()` interface
may intentionally differ from alien_signals. When behavior needs verification,
resolve the installed package through `.dart_tool/package_config.json` and read
that version's public libraries and implementation, rather than assuming the
repository's latest branch matches the consumer.

| Task | Starting point |
| --- | --- |
| Use signals in an application | `package:alien_signals/alien_signals.dart` |
| Change accessor names or API shape | Compose the surface objects |
| Work with concrete reactive nodes | `package:alien_signals/preset.dart` |
| Build different primitives or scheduling | `package:alien_signals/system.dart` |

For wrappers, node customization, or a new reactive system, read
[the integration reference](references/integration.md). Ordinary surface usage
does not require reading the engine.

The rules below describe the built-in surface and preset. A custom system or
downstream library can define different comparison, scheduling, and ownership
policies; identify those differences before applying these rules.

## Use the surface API

- Create writable state with `signal(initialValue)`, read with `value()`, and
  write with `value.set(next)`. Writing through `value(next)` is an old API.
- Derive state with `computed((previous) => expression)`. The argument is the
  last successful value, or `null` before the first success. For nullable results,
  a successful `null` is indistinguishable from no previous value.
- Keep computed getters focused on deriving values. They run lazily, cache their
  results, and track the dependencies read on the latest execution.
- Use `effect` for external work. It runs once immediately and then synchronously
  when an update requires it, unless a batch defers it.
- Call the returned effect handle to stop it, not to execute it again. The
  surface does not expose `.dispose()`, `.value`, `batch()`, or `untracked()`.
  Those names can be valid in a downstream wrapper.

This complete example checks updates and cleanup:

```dart
import 'package:alien_signals/alien_signals.dart';

void main() {
  final count = signal(0);
  final doubled = computed((_) => count() * 2);
  final events = <String>[];

  final stop = effect(() {
    final value = doubled();
    events.add('run $value');
    return () {
      events.add('cleanup $value');
    };
  });

  count.set(1);
  stop();
  count.set(2);
  assert(events.join(',') == 'run 0,cleanup 0,run 2,cleanup 2');
}
```

## Give effects an owner

Retain an independent effect's stop handle, or create related effects inside
`effectScope(() { ... })` and retain the scope's stop handle. Calling the scope
handle stops its owned effects and nested scopes. Nested children are disposed
before their parent's cleanup; children are disposed in reverse dependency order.

Return a `void Function()` cleanup synchronously from the effect callback.
Cleanup runs before re-execution and on stop, and its reads are not tracked.

Tracking, ownership, and cleanup registration are synchronous. A returned Future
is not awaited, and a cleanup produced by that Future is not registered. Read
reactive inputs before launching asynchronous work. Handle asynchronous errors,
cancellation where supported, and stale results explicitly. Effects created after
`await` need their own lifetime management.

In Flutter, use the project's adapter or an explicit lifecycle-bound bridge for
widget updates. The core package does not supply widgets or automatically track
ordinary `build` method reads. Avoid creating persistent effects on every rebuild.

## Control updates without extra machinery

Signal writes and computed results use `identical`, not `==`. Replacing a value
can notify dependents; mutating a collection and setting the same instance does
not. For intentional in-place mutation, read the holding signal inside `trigger`.
Choose replacement or mutation according to the application's data model; do not
add deep comparison, collection copies, or another cache by default.

Batch related writes with `startBatch()` and `endBatch()` in `try/finally`.
Effects flush at the outermost batch end, while reads can see current writes.
Keep the boundary synchronous. A batch defers effects; it does not roll back
writes if the body throws.

```dart
import 'package:alien_signals/alien_signals.dart';

void main() {
  final items = signal(<int>[]);
  final sizes = <int>[];
  final stop = effect(() {
    sizes.add(items().length);
  });

  startBatch();
  try {
    items().add(1);
    trigger(() => items());
    items().add(2);
    trigger(() => items());
  } finally {
    endBatch();
  }

  assert(sizes.join(',') == '0,2');
  stop();
}
```

`trigger` notifies subscribers of the values read inside its callback. It is not
a general cache reset: a derived value that remains identical can still suppress
its downstream work.

## Diagnose behavior

| Symptom | Check |
| --- | --- |
| No update | The signal was read inside the observer, the value's identity changed or was triggered, and the read happened before `await` |
| Repeated work | Effects created repeatedly, writes inside effects, and whether related writes should be batched |
| Work after disposal | Independent or asynchronously created effects, unfinished async work, and reads/creation with tracking disabled |
| Computed keeps throwing | Errors are cached until a tracked dependency is invalidated; a same-value write does not invalidate it |

A failed computed run preserves its last successful value for `previous` but
rethrows the cached error to readers. Successful recomputation clears the error.
An error without any tracked dependency has no dependency update to retry it.

Effect and cleanup exceptions propagate. Initial effect setup is not rolled back
automatically, and a throwing cleanup can interrupt further disposal. If the task
requires stronger guarantees, define that policy explicitly and consult the
integration reference before implementing it.

Verify the behavior affected by the change: observed values, execution counts,
dependency changes, and cleanup. Use deterministic tests and explicit async
completion rather than sleeps. Reuse the consumer's existing test setup.
