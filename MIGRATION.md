# Migration Guide

This guide helps you migrate from earlier versions of `alien_signals` to version 1.0.0.

## Migration from 0.x to 1.0.0

The 1.0.0 release introduces several breaking changes to improve API consistency and performance. This guide will help you update your code.

### 🔄 API Changes

#### Signal Value Access

**Before (0.x):**
```dart
final count = signal<int?>(0);

// Reading value
print(count()); // Function call syntax

// Writing value
count(1); // Function call syntax
count(null, true); // Required second parameter for nullable values
```

**After (1.0.0):**
```dart
final count = signal<int?>(0);

// Reading value
print(count.value); // Property access

// Writing value
count.value = 1; // Property assignment
count.value = null; // Direct assignment, no second parameter needed
```

#### Computed Values

**Before (0.x):**
```dart
final doubled = computed((_) => count() * 2);
print(doubled()); // Function call syntax
```

**After (1.0.0):**
```dart
final doubled = computed((_) => count.value * 2);
print(doubled.value); // Property access
```

#### Effect and EffectScope Disposal

**Before (0.x):**
```dart
final dispose = effect(() {
  print(count());
});
dispose(); // Function call

final scope = effectScope(() { /* ... */ });
scope(); // Function call
```

**After (1.0.0):**
```dart
final e = effect(() {
  print(count.value);
});
e.dispose(); // Method call

final scope = effectScope(() { /* ... */ });
scope.dispose(); // Method call
```

### 🏗️ System-Level Changes

#### Batch Operations

**Before (0.x):**
```dart
// Using batchDepth field
if (batchDepth > 0) {
  // ...
}
```

**After (1.0.0):**
```dart
// Using getBatchDepth() function
if (getBatchDepth() > 0) {
  // ...
}
```

#### Active Subscription Management

**Before (0.x):**
```dart
// Old function names
getCurrentSub();
setCurrentSub(sub);

// Removed APIs
getCurrentScope();
setCurrentScope(scope);
```

**After (1.0.0):**
```dart
// New function names
getActiveSub();
setActiveSub(sub);
```

#### Removed APIs

The following APIs have been removed in 1.0.0:

- `startTracking()` and `endTracking()` - Use inline cycle management instead
- `pauseTracking()` and `resumeTracking()` - No direct replacement
- `ReactiveFlags` enum - Replaced with int-based flags
- Signal/Computed `call()` method - Use `.value` property

### 📦 Import Changes

#### System-Level Access

**Before (0.x):**
```dart
import 'package:alien_signals/alien_signals.dart';
```

**After (1.0.0):**
```dart
import 'package:alien_signals/system.dart'; // Still available for low-level access
```

### 🛠️ Step-by-Step Migration

#### 1. Update Dependencies

Update your `pubspec.yaml`:

```yaml
dependencies:
  alien_signals: ^1.0.0
```

#### 2. Update Imports

Replace deprecated imports:

```dart
// Add this
import 'package:alien_signals/system.dart';
```

#### 3. Update Signal Usage

Find and replace signal access patterns:

```dart
// Find: signalName()
// Replace with: signalName.value

// Find: signalName(newValue)
// Replace with: signalName.value = newValue
```

#### 4. Update Effect Disposal

Update effect and scope disposal:

```dart
// Find: disposeFn()
// Replace with: disposeFn.dispose()

// Find: scopeFn()
// Replace with: scopeFn.dispose()
```

#### 5. Update System Function Calls

Replace deprecated system functions:

```dart
// Find: batchDepth
// Replace with: getBatchDepth()

// Find: getCurrentSub()
// Replace with: getActiveSub()

// Find: setCurrentSub(sub)
// Replace with: setActiveSub(sub)
```

### 🧪 Testing Your Migration

After migration, ensure your code works correctly:

1. **Run Tests**: Execute your existing test suite
2. **Check Performance**: The new version should be faster
3. **Verify Reactivity**: Ensure all signal updates trigger expected reactions

### 💡 Benefits of 1.0.0

After migration, you'll benefit from:

- **Better Performance**: Optimized reactive system with cycle-based tracking
- **Cleaner API**: More Dart-idiomatic property-based access
- **Type Safety**: Better nullability handling without extra parameters
- **Stability**: Production-ready stable API

### 🔍 Common Migration Issues

#### Issue: Nullable Signal Updates

**Problem:**
```dart
// This won't work anymore
final nullable = signal<String?>("hello");
nullable(null); // Error: method doesn't exist
```

**Solution:**
```dart
final nullable = signal<String?>("hello");
nullable.value = null; // Correct approach
```

#### Issue: Effect Disposal

**Problem:**
```dart
final e = effect(() { /* ... */ });
e(); // Error: not callable
```

**Solution:**
```dart
final e = effect(() { /* ... */ });
e.dispose(); // Correct method call
```

### 📚 Additional Resources

- [API Documentation](https://pub.dev/documentation/alien_signals/latest/)
- [Examples](example/)
- [GitHub Issues](https://github.com/medz/alien-signals-dart/issues)

### 🆘 Need Help?

If you encounter issues during migration:

1. Check this guide again for common solutions
2. Review the [API documentation](https://pub.dev/documentation/alien_signals/latest/)
3. Open an issue on [GitHub](https://github.com/medz/alien-signals-dart/issues)
4. Join the discussion in our community channels

---

**Note**: This migration guide covers the major changes from 0.x to 1.0.0. For migrations from specific beta versions, please refer to the individual changelog entries in [CHANGELOG.md](CHANGELOG.md).
