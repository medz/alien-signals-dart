---
name: alien-signals-reactivity
description: >-
  Build, review, or debug Dart reactive code using the alien_signals package.
  Use for signal/computed/effect code, missing or repeated updates, effect cleanup,
  asynchronous races, or downstream libraries built on preset.dart or system.dart.
---

# Alien Signals Reactivity

## Start at the consumer

1. Read the affected imports, call sites, and package constraint. A downstream
   library may intentionally expose `.value`, `.dispose()`, or different policies;
   preserve its public contract. This skill concerns Dart `alien_signals`, not
   the JavaScript package with a similar name.
2. Establish the observable result: which values should change, how often work
   should run, and when it should stop. For a bug, reduce the failing sequence to
   reads, writes, and disposal before changing the implementation.
3. Choose the smallest integration layer below. Read only the reference section
   needed for the task. If behavior or API availability is unclear, resolve the
   installed package through `.dart_tool/package_config.json` and inspect that
   version's public libraries and implementation.
4. Implement the change, then verify the affected behavior using the consumer's
   existing test setup. For performance work, measure execution counts or the
   relevant hot path before adding a cache, equality policy, or scheduler.

| Task | Approach | Read when needed |
| --- | --- | --- |
| Add reactive state or derived values | Surface `signal` and `computed` | [Derivation](references/usage.md#derive-values-instead-of-synchronizing-copies) |
| Connect resources, requests, or UI updates | Surface `effect` and `effectScope`, with an explicit owner | [Lifetime](references/usage.md#give-external-work-a-lifetime), [async work](references/usage.md#keep-asynchronous-results-current) |
| Fix collection updates or repeated work | Check identity and batch boundaries | [Mutation and batching](references/usage.md#notify-intentional-mutations-and-batch-related-writes) |
| Expose different accessors | Compose the surface API | [Wrappers](references/integration.md#adapt-the-surface-before-building-nodes) |
| Integrate concrete nodes | Use `preset.dart` | [Preset integration](references/integration.md#customize-preset-nodes-with-their-lifecycle) |
| Define a different reactive runtime | Implement `system.dart` policies | [System integration](references/integration.md#supply-policies-at-the-system-layer) |

## Keep these contracts visible

These are surface/preset contracts; custom downstream APIs can differ.

- **Reads establish dependencies.** Read signals inside the computed/effect that
  needs updates. Only synchronous reads are tracked, and each execution replaces
  its previous dependency set with the dependencies it actually reads.
- **Derive state with `computed`.** Use `effect` for external work. Copying a
  derived value into another writable signal adds synchronization and extra work.
- **Own every effect.** Keep its stop handle or create it synchronously in an
  owned scope. Effects run once immediately, then synchronously on relevant
  updates unless batched. Return cleanup synchronously. A Future returned from
  the callback is not awaited, and cleanup returned through it is not registered.
- **Compare by identity.** Signal writes and computed results use `identical`,
  not `==`. An in-place mutation needs `trigger` with a read of the holding signal;
  an unchanged derived identity may still suppress downstream work.
- **Batch synchronously.** Pair `startBatch()` with `endBatch()` in `finally`.
  Effects flush at the outermost end. Reads see current writes; errors do not
  roll back writes. Do not hold a batch open across `await`.

Surface spelling: `signal(initial)`, `value()`, `value.set(next)`,
`computed((previous) => ...)`, and `effect(() { ... })`. Calling an effect or scope
handle **stops** it. The surface has no `.value`, `.dispose()`, `batch()`, or
`untracked()` helper. Do not translate those names mechanically from other
signals libraries.

## Debug in this order

Trace one write through the dependent computation, observer, and cleanup. Use
the symptom to choose a check rather than changing the whole reactive graph.

| Symptom | First check | Useful verification |
| --- | --- | --- |
| Missing update | Read outside the observer, after `await`, or same-object mutation | Change a source and assert the observed value |
| Obsolete branch still triggers work | A dependency read unconditionally or a wrapper retaining old links | Switch the branch, then change the old source |
| Too many executions | Effects created repeatedly, state copied by effects, or separate related writes | Count initial execution and executions per update |
| Work continues after disposal | Detached effects, lost stop handles, or unfinished async work | Stop the owner, then write and complete pending work |
| An old request overwrites new state | Inputs read too late or stale results accepted | Complete requests in reverse order |
| Computed keeps throwing | Cached failure has not been invalidated by a tracked dependency | Change that dependency and read again |

For Flutter, use the project's adapter or an explicit lifecycle-bound bridge.
The core package has no widgets and does not automatically track ordinary
`build` reads. Creating a persistent effect on each rebuild leaks work.

## Finish with evidence

For a behavior change, assert values, execution counts, or cleanup order that
distinguish the fix from the failure. Use explicit Future completion for async
tests, not timing sleeps. Run the relevant tests and analyzer using the project's
toolchain. If runtime policy changes, select the corresponding
[integration checks](references/integration.md#verify-the-policy-you-changed).

Explain the changed behavior, the owner of any new effect, and what was verified.
If the task is a usage question, give the smallest applicable example instead of
an engine walkthrough. Report any unverified behavior as such.
