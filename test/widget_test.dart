// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:impact_trail/Community/Contributions/contribution_confirmation.dart';

void main() {
  testWidgets('Contribution confirmation shows points',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const TestApp(points: 25),
    );

    expect(find.text('+25 pts'), findsOneWidget);
    expect(find.text('View my impact'), findsOneWidget);
  });
}

class TestApp extends StatelessWidget {
  final int points;

  const TestApp({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ContributionConfirmationScreen(points: points),
    );
  }
}
