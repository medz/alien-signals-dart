import 'package:alien_signals/alien_signals.dart';

main() {
  final a = signal(1);
  final b = signal(1);

  effect(() {
    if (a.get() > 0) {
      effect(() {
        b.get();
        if (a.get() == 0) {
          throw Error();
        }
      });
    }
  });
}
