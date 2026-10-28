/// Concrete reactive nodes and scheduling helpers for custom surface APIs.
///
/// Wrap [SignalNode] and [ComputedNode] to customize value accessors.
/// These nodes share the public surface API's dependency tracking, so its
/// [effect] function can manage cleanup and nested effects for your wrappers.
///
/// {@example /example/preset_playground.dart#wrappers}
///
/// {@example /example/preset_playground.dart#usage}
///
/// @docImport 'src/preset.dart';
/// @docImport 'src/surface.dart';
library;

export 'src/preset.dart' hide system, hasChildEffect;
