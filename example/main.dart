import 'package:alien_signals/alien_signals.dart';

void main() {
  final count = signal(0);
  final doubled = computed((_) => count.get() * 2);

  effect(() {
    print('Count: ${count.get()}, D: ${doubled.get()}');
  });

  count.set(1);
  count.set(2);
}
