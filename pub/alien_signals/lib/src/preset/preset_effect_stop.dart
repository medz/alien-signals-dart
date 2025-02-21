import 'package:alien_signals/alien_signals.dart';

import 'preset_system.dart';

/// A wrapper type that provides a mechanism to stop tracking dependencies for an effect.
///
/// When called, this wrapper will:
/// 1. Start tracking dependencies for the subscriber
/// 2. Immediately end tracking, effectively clearing all dependencies
///
/// This is useful for manually stopping effects when needed.
extension type const EffectStop<T extends Subscriber>(T sub) {
  /// Stops dependency tracking for this effect subscriber.
  ///
  /// This method briefly starts tracking to clear all existing dependencies,
  /// then immediately ends tracking to prevent any further dependencies
  /// from being recorded.
  void call() {
    system.startTracking(sub);
    system.endTracking(sub);
  }
}
