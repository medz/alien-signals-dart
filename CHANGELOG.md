## 2.0.0-rc.4

Status: Unreleased

🚀 **Major Architecture Refactoring**

Version 2.0 represents a complete architectural overhaul of `alien_signals`, introducing a cleaner separation between the user-facing API and the reactive engine implementation. This release improves performance, maintainability, and developer experience while maintaining core functionality.

### 💥 Breaking Changes

#### WritableSignal API Changes
- **BREAKING**: WritableSignal now uses separate methods for reading and writing
  ```dart
  // Before (1.x): signal(value) for both read and write
  final count = signal(0);
  count(5);        // Set value
  count(5, true);  // Set with nulls parameter
  final val = count(); // Get value
  
  // After (2.0): Separate call() for read and set() for write
  final count = signal(0);
  count.set(5);    // Set value - clearer intent
  final val = count(); // Get value - unchanged
  ```
  - Removed `nulls` parameter - no longer needed with explicit `set()` method
  - `set()` method returns void instead of the value
  - Clearer separation between read and write operations

#### API Surface Restructuring
- **BREAKING**: Effect and EffectScope disposal now uses callable syntax `()` instead of `.dispose()` method
  ```dart
  // Before: effect.dispose()
  // After:   effect()
  ```
- **BREAKING**: Library exports reorganized into layers:
  - Main exports now come from `surface.dart` (Signal, WritableSignal, Computed, Effect, EffectScope, signal, computed, effect, effectScope)
  - Batch controls remain in preset exports (startBatch, endBatch, trigger)
- **BREAKING**: Low-level APIs no longer exported by default:
  - `getBatchDepth()`, `getActiveSub()`, `setActiveSub()` now require explicit import from `preset.dart`
  - Most applications should not need these APIs

#### Reactive System Changes
- **BREAKING**: `ReactiveSystem` refactored from concrete implementation to abstract class
  ```dart
  // Before: const ReactiveSystem system = PresetReactiveSystem();
  // After:  abstract class ReactiveSystem { ... }
  ```
  - `ReactiveSystem` is now an abstract base class for custom implementations
  - The preset system internally extends this abstract class
  - Enables advanced users to create custom reactive systems by extending `ReactiveSystem`
  - Most users won't interact with this directly as it's handled internally by the library

### ✨ New Features

#### Manual Trigger Function
- **NEW**: Added `trigger()` function for imperatively initiating reactive updates
  ```dart
  trigger(() {
    // Signal accesses here will propagate to subscribers
    someSignal();
  });
  ```
  - Useful for testing, forced updates, and non-reactive code integration
  - Creates temporary reactive context without persistent effects

### 🏗️ Architecture Improvements

#### Layer Separation
- Complete separation into three distinct layers:
  - `surface.dart`: High-level user-facing API with clean interfaces
  - `preset.dart`: Reactive engine with node implementations (SignalNode, ComputedNode, EffectNode)
  - `system.dart`: Core algorithms and data structures (Link, ReactiveNode, ReactiveFlags)
- Better encapsulation with private implementation classes (`_SignalImpl`, `_ComputedImpl`, `_EffectImpl`, `_EffectScopeImpl`)
- Improved inheritance hierarchy with surface implementations properly extending preset nodes

### ⚡ Performance Enhancements

- **Aggressive inlining**: Strategic `@pragma` annotations on hot paths for better performance
- **Optimized dependency tracking**: Improved cycle management and link traversal
- **Reduced allocations**: More efficient memory usage in the reactive graph
- **Better cycle detection**: Enhanced algorithm for circular dependency detection

### 📝 Documentation

- **Comprehensive API documentation**: Added detailed doc comments for all public APIs
- **Migration guide**: Complete guide for upgrading from 1.x to 2.0
- **Code examples**: Updated all examples to use new API patterns

### 🔧 Internal Changes

- Removed legacy code and deprecated patterns
- Improved type safety and null handling
- Cleaner separation of concerns between modules
- More maintainable codebase structure

### 📦 Migration

See [MIGRATION.md](MIGRATION.md#migration-from-1x-to-20) for detailed migration instructions from 1.x.

Key migration points:
1. Replace `signal(value)` with `signal.set(value)` for write operations
2. Replace `.dispose()` with `()` for effects and scopes
3. Add explicit imports for low-level APIs if needed
4. Consider using new `trigger()` function for one-time reactive operations

### 🙏 Acknowledgments

Thanks to all contributors and users who provided feedback that shaped this major release.

---

## 1.0.3

- Restrict preset developer exports to public API
- Rename update method to shouldUpdated

## 1.0.1

- Change signal interface to use `call()` instead of `.value` getter/setter

## 1.0.0

Status: Released (2025-01-15)

🎉 **First Stable Release!**

After months of development and multiple beta releases, we're excited to announce the first stable version of Alien Signals for Dart! This release brings a mature, high-performance reactive signal library to the Dart ecosystem.

### 🚀 What's New in 1.0.0

- **Stable API**: All APIs are now stable and ready for production use
- **Better Dart Integration**: Redesigned API that feels natural in Dart
- **Enhanced Performance**: Optimized reactive system with cycle-based dependency tracking
- **Comprehensive Documentation**: Complete API documentation and examples
- **Production Ready**: Battle-tested through beta releases and community feedback

### 📋 Key Features

- **Lightweight & Fast**: The lightest signal library for Dart with excellent performance
- **Simple API**: Easy-to-use `signal()`, `computed()`, and `effect()` functions
- **TypeScript Origins**: Based on the excellent [stackblitz/alien-signals](https://github.com/stackblitz/alien-signals)
- **Effect Scopes**: Manage groups of effects with `effectScope()`
- **Batch Updates**: Control reactivity with `startBatch()` and `endBatch()`

### 🎯 Getting Started

```dart
import 'package:alien_signals/alien_signals.dart';

void main() {
  // Create a signal
  final count = signal(0);

  // Create a computed value
  final doubled = computed((_) => count.value * 2);

  // Create an effect
  effect(() {
    print('Count: ${count.value}, Doubled: ${doubled.value}');
  });

  // Update the signal
  count.value++; // Prints: Count: 1, Doubled: 2
}
```

### 🔧 Migration from Beta

If you're upgrading from a beta version, please see our [Migration Guide](MIGRATION.md) for detailed instructions.

### 🙏 Acknowledgments

Special thanks to the StackBlitz team for creating the original alien-signals library and to our community for feedback during the beta period.

---

## 1.0.0-beta.4

Status: Released(2025-09-30)

- **FIX**: remove assertion in effectOper

## 1.0.0-beta.3

Status: Released(2025-09-30)

- **FEATURE**: Add `preset_developer.dart`, the basics of exporting Preset

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
