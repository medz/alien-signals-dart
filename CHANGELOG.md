## 1.0.0-beta.2

Status: Released(2025-09-29)

- Have good auto-imports, avoid auto-importing src
- `Effect`/`EffectScope`'s `call()` is renamed to `dispose()`

## 1.0.0-beta.1

Status: Released(2025-09-29)

### System

- **BREAKING CHANGE**: sync [alien-signal](https://github.com/stackblitz/alien-signals) `3.0.0` version
- **BREAKING CHANGE**: `link` add a third version count param
- **BREAKING CHANGE**: remove `startTracking` and `endTracking` API

#### Preset

- **BREAKING CHANGE**: remove deprecated `system.dart` entry point export
- **BREAKING CHANGE**: migrate `batchDepth` to `getBatchDepth()`
- **BREAKING CHANGE**: rename `getCurrentSub/setCurrentSub` to `getActiveSub/setActiveSub`
- **BREAKING CHANGE**: remove `getCurrentScope/getCurrentScope`, using `getActiveScope/setActiveScope`
- **BREAKING CHANGE**: remove signal/computed `call()`, using `.value` property
- **FEATURE**: add `Signal`,`WritableSignal`,`Computed`,`Effect` abstract interface

## 0.5.5

Status: Released (2025-09-28)

- Deprecate library entry point of `package:alien_signals/system.dart`

## 0.5.4

- perf(system): Move dirty flag declaration outside loop

## v0.5.3

> Sync upstream [alien-signals](https://github.com/stackblitz/alien-signals/commit/503c9e6cec6dea3334fefaccf76e4170d5c2da7c)<sup>v2.0.7</sup>

- **system**: Optimize isValidLink implementation
- **system**: Optimize reactive system dirty flag propagation loop
- **system**: Refactor reactive system dependency traversal logic
- **system**: Use explicit nullable types for Link variables
- **system**: Optimize reactive system flag checking logic
- **system**: Simplify recursive dependency check

## v0.5.2

- fix: Introduce per-cycle version to dedupe dependency links

## v0.5.1

- fix: Remove non-contiguous dep check

## v0.5.0

- pref: refactor: queue effects in linked effects list
- pref: Add pragma annotations for inlining to startTracking
- **BREAKING CHANGE**: Remove `pauseTracking` and `resumeTracking`
- **BREAKING CHANGE**: Remove ReactiveFlags, change flags to int type

## v0.4.4

- perf: Replace magic number with bitwise operation for clarity

## v0.4.3

- perf: Optimize computed values by using final result value in bit marks calculation (reduces unnecessary computations)
- docs: Add code comments to public API for better documentation

## v0.4.2

- pref: Add prefer-inline pragmas to core reactive methods. (Thx [#17](https://github.com/medz/alien-signals-dart/issues/17) at [@Kypsis](https://github.com/Kypsis))

## v0.4.1

- refactor: simplifying unlink sub in effect cleanup
- refactor: update pauseTracking and resumeTracking to use setCurrentSub
- refactor(preset): change queuedEffects to map like JS Array
- refactor: remove generic type from effect, effectScope
- refactor: more accurate unwatched handling
- fix: invalidate parent effect when executing effectScope
- test: update untrack tests
- test: use setCurrentSub instead of pauseTracking

**NOTE**: Sync upstream v2.0.4 version.

## v0.4.0

### Major Changes

- Sync with upstream `alien-signal` v2.0.1
- Complete package restructuring and reorganization
- Remove workspace structure in favor of a single package repository

### Features

- Implement improved reactive system architecture
- Add comprehensive signal management capabilities
  - Add `signal()` function for creating reactive state
  - Add `computed()` function for derived state
  - Add `effect()` function for side effects
  - Add `effectScope()` for managing groups of effects
- Add batch processing with `startBatch()` and `endBatch()`
- Add tracking control with `pauseTracking()` and `resumeTracking()`

### Development

- Lower minimum Dart SDK requirement to ^3.6.0 (from ^3.7.0)
- Add extensive test suite for reactivity features
- Remove separate packages in favor of a single focused package
- Update CI workflow for multi-SDK testing
- Add comprehensive examples showing signal features

### Documentation

- Expanded example code to demonstrate more signal features
