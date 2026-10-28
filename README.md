<picture>
  <source media="(prefers-color-scheme: dark)" type="image/webp" srcset="https://raw.githubusercontent.com/medz/alien-signals-dart/main/assets/mascot-patrol-dark.webp" />
  <source media="(prefers-color-scheme: dark)" type="image/gif" srcset="https://raw.githubusercontent.com/medz/alien-signals-dart/main/assets/mascot-patrol-dark.gif" />
  <source type="image/webp" srcset="https://raw.githubusercontent.com/medz/alien-signals-dart/main/assets/mascot-patrol-light.webp" />
  <img src="https://raw.githubusercontent.com/medz/alien-signals-dart/main/assets/mascot-patrol-light.gif" width="1200" alt="The Alien Signals mascot strolling, pausing, and sending signals." />
</picture>

<p align="center">
  <a href="https://pub.dev/packages/alien_signals">
    <img src="https://img.shields.io/pub/v/alien_signals?style=for-the-badge&amp;labelColor=000000&amp;color=F36F2D" alt="Alien Signals on pub.dev" />
  </a>
  <a href="https://github.com/medz/alien-signals-dart/actions/workflows/test.yml?query=branch%3Amain+event%3Apush">
    <img src="https://img.shields.io/github/actions/workflow/status/medz/alien-signals-dart/test.yml?branch=main&amp;event=push&amp;style=for-the-badge&amp;label=CI&amp;labelColor=000000" alt="CI status on main" />
  </a>
</p>

## 🎊 Get Started Today!

```dart
import 'package:alien_signals/alien_signals.dart';

void main() {
  final count = signal(0);
  final doubled = computed((_) => count() * 2);
  final stop = effect(() {
    print('Count: ${count()}, Doubled: ${doubled()}');
  }); // Count: 0, Doubled: 0

  count.set(1); // Count: 1, Doubled: 2
  stop();
  count.set(2); // The stopped effect no longer runs.
}
```

Run the [complete example](https://github.com/medz/alien-signals-dart/blob/main/example/main.dart) with `dart run example/main.dart`.

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

- **Lazy Computed Values**: Cache derived state until dependencies change
- **Effect Cleanup**: Release resources before re-running and on disposal
- **Effect Scopes**: Group effects and nested scopes under one disposal handle
- **Batch Operations**: Defer effects while applying multiple writes
- **Flexible API**: Use the surface directly or customize the preset and system

See the [runnable recipes](https://github.com/medz/alien-signals-dart/blob/main/docs/recipes.md) for each feature.

## 📦 Installation

The development version requires Dart 3.13 or later. Published version 2.3.5
supports Dart 3.8 or later.

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

- **Guide**: Layers (system/preset/surface) and core concepts. See [docs/guide.md](https://github.com/medz/alien-signals-dart/blob/main/docs/guide.md).
- **API Reference**: Generated documentation for all three public libraries. See [docs/api.md](https://github.com/medz/alien-signals-dart/blob/main/docs/api.md).
- **Recipes**: Runnable examples, lifecycle rules, and common pitfalls. See [docs/recipes.md](https://github.com/medz/alien-signals-dart/blob/main/docs/recipes.md).

### AI agent skill

The development version bundles `alien-signals-reactivity`, a skill for direct
usage and downstream surface, preset, and system integrations. It is not included
in the published 2.3.5 archive. Once your resolved dependency contains the skill,
install it from your application's or downstream package's root:

```bash
dart run skills@ get -p alien_signals
```

Select your agent when prompted, or add `--agent codex` to install into
`.agents/skills/`. The skill covers layer selection, lifecycle, batching, and
error behavior, with an integration reference loaded when needed. Skills are
discovered from direct dependencies; downstream libraries should document their
own public API and any differences from the underlying engine.

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
- **[Migration Guide](https://github.com/medz/alien-signals-dart/blob/main/MIGRATION.md)** - Upgrade instructions
