<p align="center">
  <img src="assets/logo.png" width="250"><br>
<p>

<p align="center">
  <a href="https://pub.dev/packages/alien_signals">
    <img src="https://img.shields.io/pub/v/alien_signals" alt="Alien Signals on pub.dev" />
  </a>
  <a href="https://github.com/medz/alien-signals-dart/actions/workflows/test.yml">
    <img src="https://github.com/medz/alien-signals-dart/actions/workflows/test.yml/badge.svg" alt="testing status" />
  </a>
  <a href="https://deepwiki.com/medz/alien-signals-dart"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
</p>

## 🎊 Get Started Today!

```dart
// Your reactive journey starts here
import 'package:alien_signals/alien_signals.dart';

final welcome = signal('🎉 Welcome to Alien Signals 1.0!');
effect(() => print(welcome()));
```

## 🌟 What is Alien Signals?

Alien Signals is a reactive state management library that brings the power of signals to Dart and Flutter applications. Originally inspired by [StackBlitz's alien-signals](https://github.com/stackblitz/alien-signals), our Dart implementation provides:

- **⚡ Exceptional Performance**: Proven fastest signal library in [dart-reactivity-benchmark](https://github.com/medz/dart-reactivity-benchmark)
- **🪶 Ultra Lightweight**: Minimal overhead, maximum efficiency
- **🎯 Simple API**: Intuitive `signal()`, `computed()`, and `effect()` functions
- **🔧 Production Ready**: Battle-tested through comprehensive beta releases

## 🚀 Key Features

### Core Reactive Primitives

```dart
import 'package:alien_signals/alien_signals.dart';

void main() {
  // Create reactive state
  final count = signal(0);

  // Create derived state
  final doubled = computed((_) => count() * 2);

  // Create side effects
  effect(() {
    print('Count: ${count()}, Doubled: ${doubled()}');
  });

  // Update state - triggers all dependencies
  count(1); // Output: Count: 1, Doubled: 2
}
```

### Advanced Features

- **Effect Scopes**: Group and manage effects together
- **Batch Operations**: Control when reactivity updates occur
- **Flexible API**: Both high-level presets and low-level system access

## 📊 Performance Highlights

Based on [dart-reactivity-benchmark](https://github.com/medz/dart-reactivity-benchmark) results:

- **🏆 #1 Performance**: Fastest among all Dart signal libraries
- **⚡ Optimized Updates**: Cycle-based dependency tracking
- **🎯 Minimal Overhead**: Efficient memory usage and garbage collection
- **📈 Scales Well**: Performance remains consistent with complex dependency graphs

## 📦 Installation

To install Alien Signals, add the following to your `pubspec.yaml`:

```yaml
dependencies:
  alien_signals: ^1.0.0
```

Alternatively, you can run the following command:

```bash
dart pub add alien_signals
```

## 🌍 Community & Ecosystem

### Adoptions
- **[Solidart](https://github.com/nank1ro/solidart)** - Signals for Flutter inspired by SolidJS
- **[Oref](https://github.com/medz/oref)** - Magical reactive state management for Flutter

### Growing Ecosystem
Join our thriving community of developers building reactive applications with Alien Signals!

## 📚 Resources

- **[API Documentation](https://pub.dev/documentation/alien_signals/latest/)** - Complete API reference
- **[Examples](https://github.com/medz/alien-signals-dart/tree/main/example)** - Code examples and demos
- **[Migration Guide](MIGRATION.md)** - Upgrade instructions
- **[Performance Benchmarks](https://github.com/medz/dart-reactivity-benchmark)** - Performance comparisons
