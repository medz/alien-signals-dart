import 'package:alien_signals/alien_signals.dart';

class BatchEffect<T> extends Effect<T> {
  BatchEffect(super.fn);

  @override
  T run() {
    startBatch();
    try {
      return super.run();
    } finally {
      endBatch();
    }
  }
}
