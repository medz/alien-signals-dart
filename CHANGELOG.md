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
