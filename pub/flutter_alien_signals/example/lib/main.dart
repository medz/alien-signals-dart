import 'package:flutter/material.dart';
import 'package:flutter_alien_signals/flutter_alien_signals.dart';

main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget with Signals {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final count = signal(0);

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => count.set(count.get() + 1),
            child: Text('Count: ${count.get()}'),
          ),
        ),
      ),
    );
  }
}
