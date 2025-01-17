import 'package:flutter/widgets.dart';

import '../upstream.dart';
import 'signals_widget.dart';

class SignalObserver<T> extends SignalsWidget {
  const SignalObserver(this.signal, this.builder, {super.key});

  final Signal<T> signal;
  final Widget Function(BuildContext context, T value) builder;

  @override
  Widget build(BuildContext context) {
    return builder(context, signal());
  }
}
