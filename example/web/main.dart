import 'dart:html';

import 'package:alien_signals/alien_signals.dart';

void main() {
  final count = signal(0);
  final button = querySelector('#inc') as ButtonElement;
  final output = querySelector('#value') as SpanElement;

  effect(() {
    output.text = count().toString();
  });

  button.onClick.listen((_) {
    count.set(count() + 1);
  });
}
