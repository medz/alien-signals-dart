import 'system.dart';

int batchDepth = 0;

/// Start a new batch of updates.
///
/// This function increments the batch depth counter, indicating the start of a new batch of updates.
/// Batching updates can help optimize performance by reducing the number of times the system processes changes.
///
/// {@template alien_signals.batch.example}
/// ```Example
/// final a = signal(0);
/// final b = signal(0);
///
/// effect(() {
///   print('effect run');
/// });
///
/// startBatch();
/// a.set(1);
/// b.set(1);
/// endBatch();
/// ```
/// {@endtemplate}
void startBatch() {
  ++batchDepth;
}

/// End the current batch of updates.
///
/// This function decrements the batch depth counter. If the batch depth reaches zero, it triggers the processing
/// of any queued effects that were accumulated during the batch.
///
/// {@macro alien_signals.batch.example}
void endBatch() {
  if ((--batchDepth) == 0) {
    drainQueuedEffects();
  }
}
