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

# Alien Signals for Dart

The lightest signal library for Dart, ported from [stackblitz/alien-signals](https://github.com/stackblitz/alien-signals).

> [!TIP]
> `alien_signals` is the fastest signal library currently, as shown by experimental results from 👉 [dart-reactivity-benchmark](https://github.com/medz/dart-reactivity-benchmark#score-ranking).

## Installation

To install Alien Signals, add the following to your `pubspec.yaml`:

```yaml
dependencies:
  alien_signals: latest
```

Alternatively, you can run the following command:

```bash
dart pub add alien_signals
```

## Adoption

- [Solidart](https://github.com/nank1ro/solidart) - ❤️ Signals in Dart and Flutter, inspired by SolidJS
- [Oref](https://github.com/medz/oref) - 🪄 A reactive state management library for Flutter that adds magic to any Widget with signals

## Basic Usage

```dart
import 'package:alien_signals/alien_signals.dart';

void main() {
  // Create a signal
  final count = signal(0);

  // Create a computed value
  final doubled = computed((_) => count() * 2);

  // Create an effect
  effect(() {
    print('Count: ${count()}, Doubled: ${doubled()}');
  });

  // Update the signal
  count(1); // Prints: Count: 1, Doubled: 2
}
```

## API Reference

See the [API documentation](https://pub.dev/documentation/alien_signals/latest/) for detailed information about all available APIs.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

This is a Dart port of the excellent [stackblitz/alien-signals](https://github.com/stackblitz/alien-signals) library.
