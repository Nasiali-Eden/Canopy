import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:impact_trail/Providers/location_provider.dart';
import 'package:impact_trail/Shared/widgets/location_switcher.dart';

void main() {
  testWidgets('bare switcher renders only the location label and chevron',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocationProvider(),
        child:  MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leadingWidth: 140,
              leading: LocationSwitcher(
                bare: true,
                padding: EdgeInsets.only(left: 16),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Everywhere'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    expect(find.byIcon(Icons.public_rounded), findsNothing);
    expect(find.byIcon(Icons.place_rounded), findsNothing);
    expect(find.text('All'), findsNothing);
  });
}
