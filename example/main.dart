import 'package:alien_signals/alien_signals.dart';

void basis() {
  print("\n=========== Basic Usage ===========");

  final count = signal(1);
  final doubleCount = computed((_) => count.value * 2);

  effect(() {
    print("Count is: ${count.value}");
  }); // Count is: 1

  print(doubleCount.value); // 2

  count.value = 2; // Count is: 2

  print(doubleCount.value); // 4
}

void scope() {
  print("\n=========== Effect Scope ===========");

  final count = signal(1);
  final stop = effectScope(() {
    effect(() {
      print("Count is: ${count.value}");
    }); // Count is: 1
  });

  count.value = 2; // Count is: 2
  stop();
  count.value = 3; // Not printed
}

void main() {
  basis();
  scope();
}
