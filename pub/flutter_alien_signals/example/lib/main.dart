import 'package:flutter/material.dart';
import 'package:flutter_alien_signals/flutter_alien_signals.dart';

main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget with Signals {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final a = signal(0);
    final count = signal(0);
    final doubled = computed((_) {
      return count.get() * 2 + a.get();
    });

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () {
              count.set(count.get() + 1);
              a.set(a.get() + 1);
            },
            child: Text('Count: ${count.get()}, Double: ${doubled.get()}'),
          ),
        ),
      ),
    );
  }
}
