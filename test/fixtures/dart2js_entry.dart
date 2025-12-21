import 'package:alien_signals/alien_signals.dart';

void main() {
  final count = signal(0);
  effect(() {
    count();
  });
  count.set(1);
}
