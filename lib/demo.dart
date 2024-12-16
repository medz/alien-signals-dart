import 'package:alien_signals/alien_signals.dart';

main() {
  final a = signal(0);
  effect(() => print(a.get()));
}
