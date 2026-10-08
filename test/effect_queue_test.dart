import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  for (final depth in [1, 2]) {
    test('keeps nested effects queued before a sibling at depth $depth', () {
      final innerSource = signal(0);
      final siblingSource = signal(0);
      final events = <String>[];
      var parentRuns = 0;

      void watchInner() {
        effect(() {
          events.add('inner:${innerSource()}');
        });
      }

      final parent = effect(() {
        parentRuns++;
        if (depth == 1) {
          watchInner();
        } else {
          effect(watchInner);
        }
      });
      final sibling = effect(() {
        events.add('sibling:${siblingSource()}');
      });
      addTearDown(parent.call);
      addTearDown(sibling.call);
      events.clear();

      startBatch();
      try {
        innerSource.set(1);
        siblingSource.set(1);
      } finally {
        endBatch();
      }

      expect(events, ['inner:1', 'sibling:1']);
      expect(parentRuns, 1);

      events.clear();
      innerSource.set(2);
      expect(events, ['inner:2']);
      expect(parentRuns, 1);
    });
  }

  test('keeps both nested effect groups in a batch', () {
    final first = signal(0);
    final second = signal(0);
    final events = <String>[];
    final scope = effectScope(() {
      effect(() {
        effect(() {
          events.add('first:${first()}');
        });
      });
      effect(() {
        effect(() {
          events.add('second:${second()}');
        });
      });
    });
    addTearDown(scope.call);
    events.clear();

    startBatch();
    try {
      first.set(1);
      second.set(1);
    } finally {
      endBatch();
    }

    expect(events, ['first:1', 'second:1']);
  });
}
