import 'package:alien_signals/alien_signals.dart';

void basis() {
  print("\n=========== Basic Usage ===========");

  final count = signal(1);
  final doubleCount = computed((_) => count() * 2);

  effect(() {
    print("Count is: ${count()}");
  }); // Count is: 1

  print(doubleCount()); // 2

  count.set(2); // Count is: 2

  print(doubleCount()); // 4
}

void scope() {
  print("\n=========== Effect Scope ===========");

  final count = signal(1);
  final stop = effectScope(() {
    effect(() {
      print("Count is: ${count()}");
    }); // Count is: 1
  });

  count.set(2); // Count is: 2
  stop();
  count.set(3); // Not printed
}

void main() {
  basis();
  scope();
}
