@Deprecated('Use `package:alien_signals/system.dart` instead.')
export 'system.dart';

export "src/preset.dart"
    show
        EffectScope,
        getBatchDepth,
        getCurrentSub,
        setCurrentSub,
        startBatch,
        endBatch,
        signal,
        computed,
        effect,
        effectScope;
