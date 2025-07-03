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
