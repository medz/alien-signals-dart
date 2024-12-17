import 'package:alien_signals/alien_signals.dart';

main() {
  final count = signal(0);
  final scope = effectScope();

  scope.run(() {
    effect(() {
      print(count.get());
    });
  });

  count.set(2);
}
