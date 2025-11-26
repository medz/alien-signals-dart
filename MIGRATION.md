# Migration Guide

This guide helps you migrate from earlier versions of `alien_signals` to latest version

## Migration from 1.x to 2.0

Version 2.0 represents a complete architectural refactoring of `alien_signals` that introduces a cleaner API surface and improved performance characteristics. This guide covers the breaking changes and provides detailed migration instructions.

### Overview of Changes

The 2.0 release restructures the library into two layers:
- **Surface API** (`surface.dart`): The high-level, user-facing API with clean interfaces
- **Preset System** (`preset.dart`): The low-level reactive engine implementation

This separation provides better encapsulation while maintaining full backward compatibility for core functionality.

### Breaking Changes

#### 1. WritableSignal Read/Write Separation

The WritableSignal API has been redesigned to separate read and write operations for clearer intent and better type safety.

```dart
// ❌ Version 1.x - Single call() method for both operations
final count = signal(0);
count(5);           // Set value
count(5, true);     // Set with nulls parameter  
final val = count(); // Get value

// ✅ Version 2.0 - Separate methods for clarity
final count = signal(0);
count.set(5);       // Set value - explicit write operation
final val = count(); // Get value - read-only operation
```

**Key changes:**
- Write operations now use explicit `set()` method
- Removed confusing `nulls` parameter
- `set()` returns void (previously returned the value)
- `call()` is now read-only for WritableSignal
- Clearer separation of concerns

**Rationale**: This change eliminates ambiguity about whether `call()` is reading or writing, making code more maintainable and easier to understand.

#### 2. Effect Disposal Pattern

The disposal mechanism has been unified to use callable objects instead of methods, aligning with functional programming patterns.

```dart
// ❌ Version 1.x
final e = effect(() => print(count()));
e.dispose(); // Method call

final scope = effectScope(() { /* effects */ });
scope.dispose(); // Method call

// ✅ Version 2.0
final e = effect(() => print(count()));
e(); // Callable - stops the effect

final scope = effectScope(() { /* effects */ });
scope(); // Callable - stops all effects in scope
```

**Rationale**: This change provides a more concise API and better aligns with Dart's callable object pattern.

#### 3. Library Export Restructure

The main library exports have been reorganized to provide a cleaner separation of concerns.

```dart
// Version 1.x exports (from alien_signals.dart)
export 'src/preset.dart' show
    Signal, WritableSignal, Computed, Effect, EffectScope,  // interfaces
    signal, computed, effect, effectScope,                   // factories
    getBatchDepth, getActiveSub, setActiveSub,              // low-level
    startBatch, endBatch;                                    // batch control

// Version 2.0 exports (from alien_signals.dart)
export 'src/surface.dart';  // All user-facing APIs
export 'src/preset.dart' show startBatch, endBatch, trigger;  // Only essential controls
```

**Impact**: Low-level APIs (`getBatchDepth`, `getActiveSub`, `setActiveSub`) are no longer part of the default exports.

#### 4. Access to Low-Level APIs

If your code depends on low-level reactive system APIs, you now need explicit imports:

```dart
// ❌ Version 1.x - Available by default
import 'package:alien_signals/alien_signals.dart';
final depth = getBatchDepth();
final sub = getActiveSub();

// ✅ Version 2.0 - Requires explicit import
import 'package:alien_signals/preset.dart' show getBatchDepth, getActiveSub, setActiveSub;
final depth = getBatchDepth();
final sub = getActiveSub();
```

#### 5. ReactiveSystem Refactoring

The `ReactiveSystem` has been refactored from a concrete implementation to an abstract base class:

```dart
// ❌ Version 1.x - Concrete class with preset implementation
const ReactiveSystem system = PresetReactiveSystem();

// ✅ Version 2.0 - Abstract base class for extensions
abstract class ReactiveSystem {
  bool update(ReactiveNode node);
  void notify(ReactiveNode node);
  void unwatched(ReactiveNode node);

  // Provided implementations:
  void link(ReactiveNode dep, ReactiveNode sub, int version) { ... }
  Link? unlink(Link link, ReactiveNode sub) { ... }
  void propagate(Link link) { ... }
  void shallowPropagate(Link link) { ... }
  bool checkDirty(Link link, ReactiveNode sub) { ... }
}
```

**Impact**: This is primarily an internal change that most users won't encounter directly. The reactive system is managed internally by the library. However, advanced users can now extend `ReactiveSystem` to create custom reactive behaviors. If you were previously using `PresetReactiveSystem` directly, you'll need to either use the high-level API or create a custom implementation by extending `ReactiveSystem`.

### New Features

#### The `trigger` Function

Version 2.0 introduces `trigger()` for manually initiating reactive updates without creating persistent effects:

```dart
final firstName = signal('John');
final lastName = signal('Doe');
final fullName = computed(() => '${firstName()} ${lastName()}');

// Manually trigger all fullName subscribers
trigger(() {
  fullName(); // Access within trigger causes propagation
});
```

Use cases:
- Testing reactive flows
- Forcing UI updates
- Integrating with non-reactive code

### Architecture Changes

#### Layer Separation

The codebase is now organized into distinct layers:

```
┌─────────────────────────────────────┐
│         surface.dart                │ ← User-facing API
│  (Signal, Computed, Effect, etc.)   │
├─────────────────────────────────────┤
│         preset.dart                 │ ← Reactive engine
│  (SignalNode, ComputedNode, etc.)   │
├─────────────────────────────────────┤
│         system.dart                 │ ← Core algorithms
│  (Link, ReactiveNode, etc.)         │
└─────────────────────────────────────┘
```

#### Implementation Inheritance

The surface implementations now properly extend preset nodes:

```dart
// Version 2.0 internal structure (simplified)
class SignalNode<T> extends ReactiveNode { /* preset.dart */ }
class _SignalImpl<T> extends SignalNode<T> implements WritableSignal<T> { /* surface.dart */ }

class ComputedNode<T> extends ReactiveNode { /* preset.dart */ }
class _ComputedImpl<T> extends ComputedNode<T> implements Computed<T> { /* surface.dart */ }

class EffectNode extends LinkedEffect { /* preset.dart */ }
class _EffectImpl extends EffectNode implements Effect { /* surface.dart */ }
```

This hierarchy provides better code reuse and maintainability.

### Migration Guide

#### Step 1: Update Your Dependencies

```yaml
dependencies:
  alien_signals: ^2.0.0
```

Run `dart pub upgrade` to fetch the latest version.

#### Step 2: Update Signal Write Operations

Search your codebase for signal write operations and update them:

```dart
// Find patterns like:
signalInstance(value);
signalInstance(value, true);
signalInstance(null, true);

// Replace with:
signalInstance.set(value);
signalInstance.set(value);
signalInstance.set(null);
```

**Regular expression for finding:**
```regex
// Find signal writes (excluding reads)
\b(\w+)\([^)]+\)(?!\s*[;,)])
```

**Note**: Be careful not to change read operations `signal()` which should remain unchanged.

#### Step 3: Update All Disposal Calls

Search your codebase for `.dispose()` calls and replace them:

```dart
// Search for this pattern
effectInstance.dispose();
scopeInstance.dispose();

// Replace with
effectInstance();
scopeInstance();
```

**Automated approach** (using sed or similar):
```bash
# For effects
sed -i 's/\.dispose()/()/' **/*.dart

# Review changes before committing
git diff
```

#### Step 4: Handle Low-Level API Usage

Audit your codebase for low-level API usage:

```dart
// Check for these functions:
getBatchDepth()
getActiveSub()
setActiveSub()
```

For each occurrence, either:

1. **Remove if unnecessary** - Most application code doesn't need these
2. **Add explicit import** - If genuinely required:
   ```dart
   import 'package:alien_signals/preset.dart'
     show getBatchDepth, getActiveSub, setActiveSub;
   ```

**ReactiveSystem Usage**: If your code directly uses `ReactiveSystem` or `PresetReactiveSystem`, this is likely advanced usage. The system is now an abstract class that can be extended for custom implementations. Consider whether you truly need direct system access or if the high-level API suffices. For custom reactive systems, extend the `ReactiveSystem` abstract class and implement the required methods.

#### Step 5: Leverage New Features

Consider adopting the new `trigger()` function where appropriate:

```dart
// Replace manual effect creation/disposal patterns
final tempEffect = effect(() => someComputation());
tempEffect();  // Immediately dispose

// With the cleaner trigger approach
trigger(() => someComputation());
```

#### Step 6: Verify Your Application

1. **Run tests**: `dart test`
2. **Check for warnings**: `dart analyze`
3. **Test reactive flows**: Ensure all signals, computed values, and effects work correctly
4. **Performance testing**: Verify that performance characteristics meet expectations

### Complete Migration Example

Here's a comprehensive example showing all the changes from 1.x to 2.0:

**Version 1.x Code:**
```dart
import 'package:alien_signals/alien_signals.dart';

class TodoStore {
  final todos = signal<List<String>>([]);
  final filter = signal('all');
  late final Computed<List<String>> filteredTodos;
  late final Effect autoSaveEffect;
  late final EffectScope scope;
  
  TodoStore() {
    // Using low-level APIs
    print('Batch depth: ${getBatchDepth()}');
    
    filteredTodos = computed((_) {
      final allTodos = todos();
      final currentFilter = filter();
      
      if (currentFilter == 'completed') {
        return allTodos.where((t) => t.startsWith('[x]')).toList();
      }
      return allTodos;
    });
    
    scope = effectScope(() {
      autoSaveEffect = effect(() {
        final items = todos();
        saveToStorage(items);
      });
      
      effect(() {
        print('Filtered todos: ${filteredTodos()}');
      });
    });
  }
  
  void addTodo(String todo) {
    final current = todos();
    todos([...current, todo]);  // Write with call()
  }
  
  void setFilter(String newFilter) {
    filter(newFilter);  // Write with call()
  }
  
  void dispose() {
    autoSaveEffect.dispose();  // Method call
    scope.dispose();  // Method call
  }
  
  void saveToStorage(List<String> items) {
    // Save logic
  }
}
```

**Version 2.0 Code:**
```dart
import 'package:alien_signals/alien_signals.dart';
// Explicit import for low-level APIs if needed
import 'package:alien_signals/preset.dart' show getBatchDepth;

class TodoStore {
  final todos = signal<List<String>>([]);
  final filter = signal('all');
  late final Computed<List<String>> filteredTodos;
  late final Effect autoSaveEffect;
  late final EffectScope scope;
  
  TodoStore() {
    // Using low-level APIs requires explicit import
    print('Batch depth: ${getBatchDepth()}');
    
    filteredTodos = computed((_) {
      final allTodos = todos();
      final currentFilter = filter();
      
      if (currentFilter == 'completed') {
        return allTodos.where((t) => t.startsWith('[x]')).toList();
      }
      return allTodos;
    });
    
    scope = effectScope(() {
      autoSaveEffect = effect(() {
        final items = todos();
        saveToStorage(items);
      });
      
      effect(() {
        print('Filtered todos: ${filteredTodos()}');
      });
    });
  }
  
  void addTodo(String todo) {
    final current = todos();
    todos.set([...current, todo]);  // Write with set() method
  }
  
  void setFilter(String newFilter) {
    filter.set(newFilter);  // Write with set() method
  }
  
  void dispose() {
    autoSaveEffect();  // Function call
    scope();  // Function call
  }
  
  void saveToStorage(List<String> items) {
    // Save logic
  }
  
  // New feature: Manual trigger
  void forceUpdate() {
    trigger(() {
      todos();  // Force propagation without creating an effect
    });
  }
}
```

**Summary of changes in this example:**
- ✅ Signal writes use `.set()` method instead of call with value
- ✅ Effects and scopes are disposed with `()` instead of `.dispose()`
- ✅ Low-level APIs require explicit import from `preset.dart`
- ✅ Added new `trigger()` function for manual updates

### Performance Improvements

Version 2.0 includes several performance enhancements:

- **Aggressive inlining**: Strategic use of `@pragma` annotations for hot paths
- **Reduced allocations**: Optimized link management in the dependency graph
- **Better cycle detection**: Improved algorithm for detecting circular dependencies
- **Memory efficiency**: Cleaner separation reduces memory footprint

### Troubleshooting

| Issue | Solution |
|-------|----------|
| `Too many positional arguments` | Replace `signal(value)` with `signal.set(value)` for writes |
| `The method 'dispose' isn't defined` | Replace `.dispose()` with `()` |
| `The getter 'getBatchDepth' isn't defined` | Add `import 'package:alien_signals/preset.dart' show getBatchDepth;` |
| `The getter 'getActiveSub' isn't defined` | Add `import 'package:alien_signals/preset.dart' show getActiveSub;` |
| Effects not triggering | Ensure you're calling the signal within a reactive context |
| Memory leaks | Verify all effects are properly disposed with `()` |

### Best Practices for 2.0

1. **Use explicit write operations**: Always use `.set()` for signal writes for clarity
2. **Prefer the surface API**: Use the high-level API unless you have specific low-level requirements
3. **Dispose effects properly**: Always call `effect()` when an effect is no longer needed
4. **Use effect scopes**: Group related effects for easier cleanup
5. **Leverage trigger**: Use `trigger()` for one-time reactive operations
6. **Avoid low-level APIs**: The surface API should cover most use cases

### Further Resources

- [Complete API Reference](https://pub.dev/documentation/alien_signals/latest/)
- [Performance Benchmarks](https://github.com/medz/dart-reactivity-benchmark)

---

**Need Help?** Open an issue on [GitHub](https://github.com/medz/alien-signals-dart/issues).
