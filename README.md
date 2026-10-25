<picture>
  <source media="(prefers-color-scheme: dark)" type="image/webp" srcset="assets/mascot-patrol-dark.webp" />
  <source media="(prefers-color-scheme: dark)" type="image/gif" srcset="assets/mascot-patrol-dark.gif" />
  <source type="image/webp" srcset="assets/mascot-patrol-light.webp" />
  <img src="assets/mascot-patrol-light.gif" width="1200" alt="The Alien Signals mascot strolling, pausing, and sending signals." />
</picture>

<p align="center">
  <a href="https://pub.dev/packages/alien_signals">
    <img src="https://img.shields.io/pub/v/alien_signals" alt="Alien Signals on pub.dev" />
  </a>
  <a href="https://github.com/medz/alien-signals-dart/actions/workflows/test.yml">
    <img src="https://github.com/medz/alien-signals-dart/actions/workflows/test.yml/badge.svg" alt="testing status" />
  </a>
</p>

## 🎊 Get Started Today!

```dart
// Your reactive journey starts here
import 'package:alien_signals/alien_signals.dart';

final welcome = signal('🎉 Welcome to Alien Signals!');
effect(() => print(welcome()));
```

## 🌟 What is Alien Signals?

Alien Signals is a reactive core for Dart built around a generic
`ReactiveSystem`. It includes a high-performance signals preset and a small,
ergonomic surface API. Inspired by
[StackBlitz's alien-signals](https://github.com/stackblitz/alien-signals), the
Dart implementation provides:

- **🪶 Ultra Lightweight**: Minimal overhead, maximum efficiency
- **🎯 Simple API**: Intuitive `signal()`, `computed()`, and `effect()` functions
- **🔧 Production Ready**: Battle-tested through comprehensive beta releases

## 🧭 Core Layers

- **System**: A reusable reactive graph and propagation engine (`system`).
- **Preset**: A complete signals implementation on top of the system (`preset`).
- **Surface API**: Convenience `signal/computed/effect` wrappers built on the preset.

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
  count.set(1); // Output: Count: 1, Doubled: 2
}
```

### Advanced Features

- **Effect Scopes**: Group and manage effects together
- **Batch Operations**: Control when reactivity updates occur
- **Flexible API**: Build your own surface APIs on top of the core `system` or use the `preset` implementation

## 📦 Installation

To install Alien Signals, add the following to your `pubspec.yaml`:

```yaml
dependencies:
  alien_signals: ^2.3.5
```

Alternatively, you can run the following command:

```bash
dart pub add alien_signals
```

## 📖 Documentation

- **Guide**: Layers (system/preset/surface) and core concepts. See [docs/guide.md](docs/guide.md).
- **API Reference**: System, preset, and surface APIs. See [docs/api.md](docs/api.md).
- **Recipes**: Practical patterns and pitfalls. See [docs/recipes.md](docs/recipes.md).

## 🌍 Community & Ecosystem

### Adoptions

- **[Solidart](https://github.com/nank1ro/solidart)** - Signals for Flutter inspired by SolidJS
- **[Oref](https://github.com/medz/oref)** - Magical reactive state management for Flutter
- **[flutter_compositions](https://github.com/yoyo930021/flutter_compositions)** - Vue-inspired reactive building blocks for Flutter
- **[ZenBus](https://pub.dev/packages/zenbus)** - A high-performance, flexible event bus for Flutter applications
- **[ZenSignals](https://github.com/definev/zensuite/tree/main/packages/zensignals)** - Signal-based state bridging Flutter's ValueNotifier and ValueListenable APIs
- **[alien_signals_translator](https://pub.dev/packages/alien_signals_translator)** - Reactive JSON-based localization with ICU message formatting for Flutter
- **[signal_router](https://github.com/wildwind123/signal-router)** - Signal-based routing and navigation state for Dart and Flutter (alpha)

### Growing Ecosystem

Join our thriving community of developers building reactive applications with Alien Signals!

## 📚 Resources

- **[API Documentation](https://pub.dev/documentation/alien_signals/latest/)** - Complete API reference
- **[Examples](https://github.com/medz/alien-signals-dart/tree/main/example)** - Code examples and demos
- **[Migration Guide](MIGRATION.md)** - Upgrade instructions
