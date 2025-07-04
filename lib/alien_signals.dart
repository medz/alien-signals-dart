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

/// Returns the current batch depth.
///
/// The batch depth represents how many nested batches are currently active.
/// A value of 0 means no batching is currently active.
int get batchDepth => preset.batchDepth;
