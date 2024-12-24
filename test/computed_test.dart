import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

import 'src/recursion_computed.dart';

void main() {
  test('should correctly propagate changes through computed signals', () {
    final source = signal(0);
    final c1 = computed((_) => source.get() % 2);
    final c2 = computed((_) => c1.get());
    final c3 = computed((_) => c2.get());

    c3.get();
    source.set(1);
    c2.get();
    source.set(3);

    expect(c3.get(), equals(1));
  });

  test('should custom computed support recursion', () {
    final logs = <String>[];
    final a = signal(0);
    final b = RecursiveComputed<void>((_) {
      if (a.get() == 0) {
        logs.add('b-0');
        a.set(100);
        logs.add('b-1 ${a.get()}');
        a.set(200);
        logs.add('b-2 ${a.get()}');
      } else {
        logs.add('b-2 ${a.get()}');
      }
    });

    b.get();

    expect(logs, ['b-0', 'b-1 100', 'b-2 200', 'b-2 200']);
  });
}
