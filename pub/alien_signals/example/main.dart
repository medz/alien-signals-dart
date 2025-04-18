import 'package:alien_signals/alien_signals.dart';

void main() {
  final count = signal(0);
  final doubled = computed((_) => count() * 2);

  effect(() {
    print('Count: ${count()}, D: ${doubled()}');
  });

  count(1);
  count(2);
}
