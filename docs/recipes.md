# Recipes

Each example is a standalone program. Run it from the package root with
`dart run example/<name>.dart`, or enable its assertions with
`dart --enable-asserts run example/<name>.dart`.

| Task | Example | Behavior to notice |
| --- | --- | --- |
| Read and write reactive state | [main.dart](../example/main.dart) | Effects run immediately, observe writes, and stop when their handle is called. |
| Cache derived state | [computed.dart](../example/computed.dart) | The getter runs lazily; unchanged reads reuse its result. |
| Clean up an effect | [effect_cleanup.dart](../example/effect_cleanup.dart) | Cleanup runs before the next execution and on stop. |
| Dispose a group of effects | [effect_scope.dart](../example/effect_scope.dart) | Stopping the scope also stops its nested scopes. |
| Batch writes | [batch.dart](../example/batch.dart) | Effects wait until the outermost batch ends; reads still see updated values. |
| Notify after mutating a collection | [trigger.dart](../example/trigger.dart) | Setting the same object does not notify; `trigger` explicitly notifies its readers. |
| Customize value accessors | [preset_playground.dart](../example/preset_playground.dart) | Preset nodes work with the public effect lifecycle. |
| Manage a dependency graph | [system.dart](../example/system.dart) | Linking, notification, and unlinking are independent of value storage. |
| Update a web page | [Web demo](../example/web/README.md) | Compile the browser entrypoint separately. |

## Effect lifetimes

Retain and stop effects in long-lived contexts, or create them inside a scope
whose handle you retain. Return cleanup synchronously to release resources
before the next execution and on disposal. Cleanup reads are not dependencies;
nested effects and scopes are disposed before their parent's cleanup.

Only synchronous reads are tracked. Read reactive inputs before starting
asynchronous work. Effects created after an `await` require their own disposal.

## Batching

Always pair `startBatch()` with `endBatch()` in a `finally` block so an exception
does not leave later effects deferred. Nested batches flush at the outermost
`endBatch()`.

## Computed failures

A computed getter caches errors until a tracked dependency changes. A successful
retry clears the error, and the previous-value argument remains the last
successful value after a failure. Prefer a computed value for derived state
instead of an effect that writes another signal.

For layer selection and implementation details, see the [guide](guide.md).
