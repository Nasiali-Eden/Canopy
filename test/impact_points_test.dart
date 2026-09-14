import 'package:flutter_test/flutter_test.dart';

import 'package:impact_trail/Services/Contributions/contribution_service.dart';

void main() {
  test('estimateImpactPoints: Time contribution', () {
    final points =
        ContributionService().estimateImpactPoints(type: 'Time', hours: 2.0);
    expect(points, 20);
  });

  test('estimateImpactPoints: Materials contribution', () {
    final points = ContributionService().estimateImpactPoints(
        type: 'Materials', materials: ['bags', 'gloves', 'water']);
    expect(points, 20);
  });
}
