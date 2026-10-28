/// Signals, computed values, and effects for reactive state.
///
/// Start with [signal] and [computed], observe changes with [effect], and
/// call the returned effect handle when its work is no longer needed.
/// Use [effectScope] to group lifetimes and [startBatch] to group writes.
///
/// {@example /example/main.dart#basic}
///
/// @docImport 'src/surface.dart';
/// @docImport 'src/preset.dart';
library;

export 'src/preset.dart'
    show EffectCallback, EffectCleanup, startBatch, endBatch, trigger;
export 'src/surface.dart';
