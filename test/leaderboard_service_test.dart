import 'package:flutter_test/flutter_test.dart';
import 'package:impact_trail/Services/Rank/leaderboard_service.dart';

void main() {
  test('equal scores share competition ranks starting at one', () {
    const entries = [
      RankEntry(userId: 'a', name: 'A', points: 20),
      RankEntry(userId: 'b', name: 'B', points: 20),
      RankEntry(userId: 'c', name: 'C', points: 10)
    ];
    expect(LeaderboardService.positionOf(entries, 'a'), 1);
    expect(LeaderboardService.positionOf(entries, 'b'), 1);
    expect(LeaderboardService.positionOf(entries, 'c'), 3);
    expect(LeaderboardService.positionOf(entries, 'missing'), isNull);
  });
}
