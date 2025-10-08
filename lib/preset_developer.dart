/// Alien Signal preset for developers.
///
/// You can use the presets to further customize.
library;

export 'src/preset.dart'
    hide
        link,
        unlink,
        propagate,
        checkDirty,
        shallowPropagate,
        batchDepth,
        activeSub,
        queuedEffects,
        queuedEffectsTail,
        Signal,
        WritableSignal,
        Computed,
        Effect,
        EffectScope,
        PresetReactiveSystem;
