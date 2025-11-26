import 'package:alien_signals/alien_signals.dart';
import 'package:test/test.dart';

void main() {
  test('should not throw when triggering with no dependencies', () {
    trigger(() {});
  });

  test('should trigger updates for dependent computed signals', () {
    final arr = signal(<int>[]);
    final length = computed((_) => arr().length);

    expect(length(), 0);
    arr().add(1);
    trigger(() => arr());
    expect(length(), 1);
  });

  test('should trigger updates for the second source signal', () {
    final src1 = signal(<int>[]);
    final src2 = signal(<int>[]);
    final length = computed((_) => src2().length);

    expect(length(), 0);
    src2().add(1);
    trigger(() {
      src1();
      src2();
    });
    expect(length(), 1);
  });

  test('should trigger effect once', () {
    final src1 = signal(<int>[]);
    final src2 = signal(<int>[]);

    int triggers = 0;

    effect(() {
      triggers++;
      src1();
      src2();
    });

    expect(triggers, 1);
    trigger(() {
      src1();
      src2();
    });
    expect(triggers, 2);
  });

  test('should not notify the trigger function sub', () {
    final src1 = signal<List<int>>([]);
    final src2 = computed((_) => src1());

    effect(() {
      src1();
      src2();
    });

    trigger(() {
      src1();
      src2();
    });
  });
}
