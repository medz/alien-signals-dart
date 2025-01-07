import 'package:flutter/material.dart';
import 'package:flutter_alien_signals/flutter_alien_signals.dart';

main() {
  runApp(const ExampleApp());
}

class ExampleApp extends SignalsWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final count = signal(0);
    void increment() => count.value++;

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: increment,
            child: SignalObserver(count, (_, count) {
              return Text('Count: $count');
            }),
          ),
        ),
      ),
    );
  }
}
