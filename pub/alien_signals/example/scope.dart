import 'package:alien_signals/alien_signals.dart';

void main() {
  final count = signal(0);
  final doubled = computed((_) => count() * 2);

  // Create an effect that will run whenever count or doubled changes
  final stop = effectScope(() {
    effect(() => print('scope count: ${count()}'));
    effect(() => print('scope double count: ${doubled()}'));
  });

  // Without scope effect
  effect(() {
    print('Count: ${count()}, Double: ${doubled()}');
  }); // print count: 0, double count: 0

  // print scope of - scope count: 1\n scope double count: 2
  // print of - Count: 1, Double: 2
  count(1);

  stop(); // stop the scope
  count(2); // print of - Count: 2, Double: 4
}
