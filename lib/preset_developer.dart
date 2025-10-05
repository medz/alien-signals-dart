/// Alien Signal preset for developers.
///
/// You can use the presets to further customize.
library;

import 'src/preset.dart';

export 'src/preset.dart'
    show
        PresetComputed,
        PresetEffect,
        PresetEffectScope,
        PresetWritableSignal,
        system;

extension PresetWritableSignalLegacy<T> on PresetWritableSignal<T> {
  @Deprecated('Use `cachedValue` instead.')
  T get previousValue => cachedValue;

  @Deprecated('Use `cachedValue` instead.')
  set previousValue(T value) => cachedValue = value;
}
