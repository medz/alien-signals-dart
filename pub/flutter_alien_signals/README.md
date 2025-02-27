<p align="center">
  <img src="https://github.com/stackblitz/alien-signals/raw/master/assets/logo.png" width="250"><br>
<p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_alien_signals">
    <img src="https://img.shields.io/pub/v/flutter_alien_signals" alt="Alien Signals on pub.dev" />
  </a>
</p>

# Flutter Alien Signals

Flutter Alien Signals is a Flutter binding based on [Alien Signals](https://github.com/medz/alien-signals-dart). It seamlessly integrates with Flutter Widgets, providing elegant usage methods and intuitive state management.

## Installation

To install Alien Signals, add the following to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_alien_signals: latest
```

Alternatively, you can run the following command:

```bash
flutter pub add flutter_alien_signals
```

## Example

```dart
class Counter extends SignalsWidget {
  const Counter({super.key});

  @override
  Widget build(BuildContext context) {
    final count = signal(0);
    void increment() => count.value++;

    return Scaffold(
      body: Center(
        child: Text('Count: ${count()}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: increment,
        child: const Icon(Icons.plus_one),
      ),
    );
  }
}
```

## `StatelessWidget`

Integrating with `StatelessWidget` is very simple, just use the `Signals` mixin:

```dart
class MyWidget extends StatelessWidget with Signals {
  ...
}
```

If you're writing a brand new Widget, there's a simpler `SignalsWidget` base class:

```dart
class MyWidget extends SignalsWidget {
  ...
}
```

## `StatefulWidget`

Integration with `StatefulWidget` is similar, we use the `StateSignals` mixin:

```dart
class MyWidget extends StatefulWidget with StateSignals {
  State<MyWidget> createState() {
    return _MyWidgetState();
  }
}

class _MyWidgetState extends State<MyWidget> {
  final a = signal(0);
  ...
}
```

> [!NOTE]
>
> You can freely use signal-related APIs in the `build` method in both `StatelessWidget` and `StatefulWidget`.

## Observer

If you don't want your signal/computed to affect the entire current Widget, but instead only trigger local rebuilds when the signal's value updates, you should use `SignalObserver`:

```dart
class MyWidget extends SignalsWidget {
  @override
  Widget build(BuildContext context) {
    final a = signal(0);
    final b = signal(0);

    return Column(
      children: [
        // When a value updates, it will trigger a rebuild of the entire MyWidget.
        Text('A: ${a.get()}'),
        // When b value updates, only this Text widget will be rebuild.
        SignalObserver(b, (_, value) => Text('B: $value')),
      ],
    );
  }
}
```

## Compat (`.value` getter)

Perhaps Alien Signals' `get()` and `set()` are not concise enough, so we've prepared the `.value` getter for you:

```dart
final count = signal(0);
count.value++; // count.set(count.get() + 1);
```

## Notes

1. Apart from using `with Signals/StateSignals` in your Widget, other APIs are consistent with Alien Signals.
2. You can use Alien Signals API in any code in the global scope, it will handle the Scope automatically.
