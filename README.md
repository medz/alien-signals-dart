<p align="center">
	<img src="https://github.com/stackblitz/alien-signals/raw/master/assets/logo.png" width="250"><br>
<p>

<p align="center">
	<a href="https://pub.dev/packages/alien_signals">
	   <img src="https://img.shields.io/pub/v/alien_signals" alt="Alien Signals on pub.dev" />
	</a>
</p>

# Alien Signals for Dart

The lightest signal library for Dart, ported from [stackblitz/alien-signals](https://github.com/stackblitz/alien-signals).

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  alien_signals: latest
```

## Basic Usage

```dart
import 'package:alien_signals/alien_signals.dart';

void main() {
  // Create a signal
  final count = signal(0);

  // Create a computed value
  final doubled = computed((_) => count.get() * 2);

  // Create an effect
  effect(() {
    print('Count: ${count.get()}, Doubled: ${doubled.get()}');
  });

  // Update the signal
  count.value = 1; // Prints: Count: 1, Doubled: 2
}
```

## Core Concepts

### Signals

Signals are reactive values that notify subscribers when they change:

```dart
final name = signal('Alice');

print(name.get()); // Get value using call `get` fn.
name.set('Bob');   //Set value using call `set` fn.

// or
print(name()); // Get value using call syntax
name('Bob');   // Set value using call syntax

// or
print(name.value); // Get using property syntax
name.value = 'Bob'; // Set using property syntax
```

### Computed Values

Computed values automatically derive from other reactive values:

```dart
final firstName = signal('John');
final lastName = signal('Doe');
final fullName = computed((_) => '${firstName.get()} ${lastName.get()}');

effect(() => print(fullName())); // Prints: John Doe
lastName.value = 'Smith';        // Prints: John Smith
```

### Effects

Effects run automatically when their dependencies change:

```dart
final user = signal('guest');

final e = effect(() {
  print('Current user: ${user()}');
});

// Cleanup when done
e.stop();
```

### Effect Scopes

Group and manage related effects:

```dart
final scope = effectScope();
scope.run(() {
  // Effects created here are grouped
  effect(() => print('Effect 1'));
  effect(() => print('Effect 2'));
});

// Clean up all effects in scope
scope.stop();
```

### Compat

Allows you to manipulate signals using the `.value` property:

```dart
import 'package:alien_signals/alien_signals.dart';
import 'package:alien_signals/compat.dart';

void main() {
  final count = signal(0);
  effect(() => print(count.value); // print 0

  count.value++; // print 1
}
```

## API Reference

See the [API documentation](https://pub.dev/documentation/alien_signals/latest/) for detailed information about all available APIs.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

This is a Dart port of the excellent [stackblitz/alien-signals](https://github.com/stackblitz/alien-signals) library.
