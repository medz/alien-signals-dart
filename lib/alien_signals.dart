import "src/preset.dart" as preset show batchDepth;

export 'system.dart';
export "src/preset.dart"
    show
        EffectScope,
        getCurrentSub,
        setCurrentSub,
        getCurrentScope,
        setCurrentScope,
        startBatch,
        endBatch,
        pauseTracking,
        resumeTracking,
        signal,
        computed,
        effect,
        effectScope;

int get batchDepth => preset.batchDepth;
