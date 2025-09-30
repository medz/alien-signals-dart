/// Alien signals preset library.
library;

export "src/preset.dart"
    show
        Signal,
        WritableSignal,
        Computed,
        Effect,
        EffectScope,
        getBatchDepth,
        getActiveSub,
        setActiveSub,
        startBatch,
        endBatch,
        signal,
        computed,
        effect,
        effectScope;
export 'src/preset_legacy.dart';
