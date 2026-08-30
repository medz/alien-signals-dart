import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test('caches an initial error for non-nullable values', () {
    final error = StateError('boom');
    int calls = 0;
    final value = computed<int>((_) {
      calls++;
      throw error;
    });

    final first = _captureError(() => value());
    final second = _captureError(() => value());

    expect(first.$1, same(error));
    expect(second.$1, same(error));
    expect(second.$2.toString(), first.$2.toString());
    expect(calls, 1);
  });

  test('caches an initial error for nullable values', () {
    final error = StateError('boom');
    int calls = 0;
    final value = computed<int?>((_) {
      calls++;
      throw error;
    });

    expect(() => value(), throwsA(same(error)));
    expect(() => value(), throwsA(same(error)));
    expect(calls, 1);
  });

  test('recomputes after an error when a dependency changes', () {
    final source = signal(0);
    final error = StateError('boom');
    final previousValues = <int?>[];
    int calls = 0;
    final value = computed<int>((previous) {
      calls++;
      previousValues.add(previous);
      final next = source();
      if (next == 1) throw error;
      return next;
    });

    expect(value(), 0);
    source.set(1);
    expect(() => value(), throwsA(same(error)));
    expect(() => value(), throwsA(same(error)));
    expect(calls, 2);

    source.set(2);
    expect(value(), 2);
    expect(previousValues, [null, 0, 0]);
    expect(calls, 3);
  });

  test('notifies effects when recovering to the previous value', () {
    final shouldThrow = signal(false);
    final error = StateError('boom');
    final values = <Object>[];
    int calls = 0;
    final value = computed<int>((_) {
      calls++;
      if (shouldThrow()) throw error;
      return 1;
    });
    final stop = effect(() {
      try {
        values.add(value());
      } on Object catch (error) {
        values.add(error);
      }
    });

    expect(values, [1]);
    shouldThrow.set(true);
    expect(values, [1, error]);
    shouldThrow.set(false);
    expect(values, [1, error, 1]);
    expect(calls, 3);

    stop();
  });

  test('links outer computed values before rethrowing', () {
    final source = signal(0);
    final error = StateError('boom');
    int innerCalls = 0;
    int outerCalls = 0;
    final inner = computed<int>((_) {
      innerCalls++;
      final value = source();
      if (value == 0) throw error;
      return value;
    });
    final outer = computed<int>((_) {
      outerCalls++;
      try {
        return inner() * 2;
      } on Object {
        return -1;
      }
    });

    expect(outer(), -1);
    expect(outer(), -1);
    expect(innerCalls, 1);
    expect(outerCalls, 1);

    source.set(2);
    expect(outer(), 4);
    expect(innerCalls, 2);
    expect(outerCalls, 2);
  });

  test('replaces a cached error after a dependency changes', () {
    final source = signal(0);
    final errors = <Object>[];
    int calls = 0;
    final value = computed<int>((_) {
      calls++;
      throw StateError('boom ${source()}');
    });
    final stop = effect(() {
      try {
        value();
      } on Object catch (error) {
        errors.add(error);
      }
    });

    expect(errors.single.toString(), 'Bad state: boom 0');
    source.set(1);
    expect(errors.map((error) => error.toString()), [
      'Bad state: boom 0',
      'Bad state: boom 1',
    ]);
    expect(calls, 2);
    expect(() => value(), throwsA(same(errors.last)));
    expect(calls, 2);

    stop();
  });

  test('cleans up dependencies collected before an error', () {
    final useLeft = signal(true);
    final left = signal(0);
    final right = signal(10);
    final error = StateError('boom');
    int calls = 0;
    final value = computed<int>((_) {
      calls++;
      final next = useLeft() ? left() : right();
      if (next < 0) throw error;
      return next;
    });

    expect(value(), 0);
    left.set(-1);
    expect(() => value(), throwsA(same(error)));

    useLeft.set(false);
    expect(value(), 10);
    expect(calls, 3);

    left.set(1);
    expect(value(), 10);
    expect(calls, 3);

    right.set(-1);
    expect(() => value(), throwsA(same(error)));
    expect(calls, 4);
  });

  test('recovers from an error to a nullable value', () {
    final source = signal(0);
    final error = StateError('boom');
    int calls = 0;
    final value = computed<int?>((_) {
      calls++;
      if (source() == 0) throw error;
      return null;
    });

    expect(() => value(), throwsA(same(error)));
    expect(() => value(), throwsA(same(error)));
    expect(calls, 1);

    source.set(1);
    expect(value(), isNull);
    expect(calls, 2);
  });
}

(Object, StackTrace) _captureError(void Function() callback) {
  try {
    callback();
  } on Object catch (error, stackTrace) {
    return (error, stackTrace);
  }
  throw StateError('Expected callback to throw.');
}
