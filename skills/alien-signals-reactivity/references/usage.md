# Surface usage

Use the public `package:alien_signals/alien_signals.dart` API for these recipes.
Each Dart block is a complete program; assertions describe the expected behavior.

## Derive values instead of synchronizing copies

If `total` is always `price * quantity`, a writable total synchronized by
`effect(() => total.set(price() * quantity()))` creates an unnecessary observer
and another state value to keep consistent. Make the relationship a computed:

```dart
import 'package:alien_signals/alien_signals.dart';

void main() {
  final price = signal(10);
  final quantity = signal(2);
  var evaluations = 0;
  final total = computed((_) {
    evaluations++;
    return price() * quantity();
  });

  assert(evaluations == 0);
  assert(total() == 20);
  assert(total() == 20);
  assert(evaluations == 1);
  quantity.set(3);
  assert(total() == 30);
  assert(evaluations == 2);
}
```

Read `price()` and `quantity()` inside the getter. Capturing their values before
creating the computed leaves it with snapshots and no dependencies. Conditional
getters track only the branch they execute; do not read both branches merely to
force subscriptions.

`previous` is the last successful computed value, or `null` before any success.
For nullable results, `null` cannot distinguish those two cases. Getter failures
are cached until a tracked dependency is invalidated; a failed run preserves the
last successful value. A same-value write does not invalidate the error, and a
getter with no dependencies has no dependency update to retry it.

## Give external work a lifetime

Create effects once at the owning object's initialization boundary and stop them
at its disposal boundary. Use a scope for effects that share an owner. Cleanup
runs before re-execution and on stop; return it from the callback synchronously.

```dart
import 'package:alien_signals/alien_signals.dart';

void main() {
  final channel = signal('news');
  final events = <String>[];

  final stop = effectScope(() {
    effect(() {
      final name = channel();
      events.add('subscribe $name');
      return () {
        events.add('unsubscribe $name');
      };
    });
  });

  channel.set('sports');
  stop();
  channel.set('weather');
  assert(
    events.join(',') ==
        'subscribe news,unsubscribe news,subscribe sports,unsubscribe sports',
  );
}
```

Replace the event recording with the subscription and its cancellation API.
Cleanup reads are untracked. Nested children stop before the parent's cleanup,
in reverse dependency order. Effects and scopes created after `await` are not
owned by the earlier callback; retain and dispose those handles separately.

Effect and cleanup exceptions propagate. Failed initial setup can leave
subscriptions behind without returning a stop handle, and throwing cleanup can
interrupt further disposal. Handle expected failures at the resource boundary;
do not promise automatic setup rollback or complete teardown after an exception.

## Keep asynchronous results current

An `async` effect callback cannot return registered cleanup through its Future.
Read inputs in a synchronous effect, launch the operation, and return cleanup
immediately. Guard both success and failure when stale completions must be ignored:

```dart
import 'dart:async';

import 'package:alien_signals/alien_signals.dart';

Future<void> main() async {
  final query = signal('old');
  final result = signal<String?>(null);
  final requests = <String, Completer<String>>{};
  final pending = <Future<void>>[];
  final errors = <Object>[];

  Future<String> search(String term) {
    final request = Completer<String>();
    requests[term] = request;
    return request.future;
  }

  final stop = effect(() {
    final term = query();
    var active = true;
    pending.add(
      Future<String>.sync(() => search(term)).then<void>(
        (value) {
          if (active) result.set(value);
        },
        onError: (Object error, StackTrace stack) {
          if (active) errors.add(error);
        },
      ),
    );
    return () {
      active = false;
    };
  });

  query.set('new');
  requests['new']!.complete('new result');
  requests['old']!.complete('old result');
  await Future.wait(pending);
  assert(result() == 'new result' && errors.isEmpty);

  query.set('failing');
  query.set('late');
  stop();
  requests['failing']!.completeError(StateError('obsolete request'));
  requests['late']!.complete('too late');
  await Future.wait(pending);
  assert(result() == 'new result' && errors.isEmpty);
}
```

The completers and `pending` list make this example deterministic. In application
code, use the real request and error handler. This guard suppresses stale
completions; it does not cancel the request. Use the resource's cancellation API
in cleanup when available. If teardown must await asynchronous cancellation,
expose that completion through the owner's lifecycle; an effect stop handle is
synchronous.

## Notify intentional mutations and batch related writes

`items().add(x); items.set(items());` writes the same identity and does not notify.
Choose replacement when the data model uses immutable values; for intentional
in-place mutation, call `trigger(() => items())`. Read only the signals you
intend to notify inside `trigger`.

```dart
import 'package:alien_signals/alien_signals.dart';

void main() {
  final items = signal(<int>[]);
  final sizes = <int>[];
  final stop = effect(() {
    sizes.add(items().length);
  });

  startBatch();
  try {
    items().add(1);
    trigger(() => items());
    items().add(2);
    trigger(() => items());
  } finally {
    endBatch();
  }

  assert(sizes.join(',') == '0,2');
  stop();
}
```

A computed returning the same list may still suppress its own observers after
the source is triggered. Derive the scalar or other value the observer actually
needs, or choose replacement if the consumer's contract depends on identity.
`trigger` is not a general computed-cache reset.

Keep batches synchronous and always close them in `finally`. Batching defers
effects; it does not hide writes from reads or undo writes after an exception.
