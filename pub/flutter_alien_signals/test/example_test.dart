import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/main.dart' show ExampleApp;

void main() {
  group('ExampleApp', () {
    testWidgets('work', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      expect(find.text('Count: 0'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Count: 0'));
      await tester.pump();
      expect(find.text('Count: 1'), findsOneWidget);
    });
  });
}
