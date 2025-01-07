import 'package:alien_signals/alien_signals.dart';

void main() {
  final count = signal(0);
  final doubled = computed((_) => count.get() * 2);

  // Create an effect that will run whenever count or doubled changes
  final scope = effectScope();
  scope.run(() {
    effect(() => print('scope count: ${count.get()}'));
    effect(() => print('scope double count: ${doubled.get()}'));
  }); // print count: 0 \n double count: 0

  // Without scope effect
  effect(() {
    print('Count: ${count.get()}, Double: ${doubled.get()}');
  }); // print count: 0, double count: 0

  // print scope of - scope count: 1\n scope double count: 2
  // print of - Count: 1, Double: 2
  count.set(1);

  scope.stop(); // stop the scope
  count.set(2); // print of - Count: 2, Double: 4
}
