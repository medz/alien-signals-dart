import 'package:alien_signals/preset.dart';
import 'package:test/test.dart';

void main() {
  test('should correctly propagate changes through computed signals', () {
    final source = signal(0);
    final c1 = computed((_) => source() % 2);
    final c2 = computed((_) => c1());
    final c3 = computed((_) => c2());

    c3();
    source(1);
    c2();
    source(3);

    expect(c3(), equals(1));
  });
}
