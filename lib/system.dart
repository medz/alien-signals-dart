/// A dependency graph and propagation engine for custom reactive primitives.
///
/// Extend [ReactiveSystem] to supply update, scheduling, and cleanup behavior.
/// Use [ReactiveNode] and [Link] to represent the graph. Value storage,
/// active-subscriber tracking, and callback execution belong to your layer.
///
/// This manual graph demonstrates linking, notification, and unlinking:
///
/// {@example /example/system.dart#system}
///
/// {@example /example/system.dart#graph}
///
/// @docImport 'src/system.dart';
library;

export 'src/system.dart' hide Stack;
