/// <p align="center">
/// 	<img src="https://github.com/stackblitz/alien-signals/raw/master/assets/logo.png" width="250"><br>
/// <p>
///
/// <p align="center">
/// 	<a href="https://pub.dev/packages/alien_signals">
/// 		<img src="https://img.shields.io/pub/v/alien_signals" alt="Alien Signals on pub.dev" />
/// 	</a>
/// </p>
///
/// # Alien Signals for Dart
/// The lightest signal library for Dart, ported from [stackblitz/alien-signals](https://github.com/stackblitz/alien-signals).
///
/// > [!TIP]
/// > Alien Signals is the fastest signal library currently, as shown by experimental results from 👉 [dart-reactivity-benchmark](https://github.com/medz/dart-reactivity-benchmark#score-ranking).
///
/// ## Installation
///
/// To install Alien Signals, add the following to your `pubspec.yaml`:
///
/// ```yaml
/// dependencies:
///   alien_signals: latest
/// ```
///
/// Alternatively, you can run the following command:
///
/// ```bash
/// dart pub add alien_signals
/// ```
///
/// ## Links
/// - Github repo 👉 [medz/alien-signals-dart](https://github.com/medz/alien-signals-dart)
/// - Funding:
///   - [Support @medz on GitHub](https://github.com/sponsors/medz)
///   - [Support @medz on OpenCollective](https://opencollective.com/openodroe)
library;

export 'src/computed.dart';
export 'src/effect.dart';
export 'src/effect_scope.dart';
export 'src/signal.dart';
export 'src/system.dart';
export 'src/types.dart';
