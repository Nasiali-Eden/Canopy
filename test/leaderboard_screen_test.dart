import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:impact_trail/Models/user.dart';
import 'package:impact_trail/Community/Recognition/leaderboard_screen.dart';
import 'package:impact_trail/Services/Rank/leaderboard_service.dart';

class FakeRanking implements LeaderboardService {
  final bool fail;
  FakeRanking({this.fail = false});
  @override
  Stream<List<RankEntry>> watchPeopleLeaderboard({int limit = 50}) => fail ? Stream.error(Exception('Offline')) : Stream.value(const [RankEntry(userId:'leader',name:'Leader',points:500)]);
  @override
  Stream<int> watchOwnPoints(String uid) => Stream.value(20);
  @override
  Future<PersonalRank> getPersonalRank(String uid) async => const PersonalRank(RankEntry(userId:'me',name:'Member',points:20),151,11,pendingPoints:10);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
void main() {
  testWidgets('personal rank remains visible outside fetched leaders on a narrow display', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360,800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(Provider<F_User?>.value(value:F_User(uid:'me'),child:MaterialApp(home:LeaderboardScreen(service:FakeRanking()))));
    await tester.pumpAndSettle();
    expect(find.text('#151'), findsOneWidget);
    expect(find.text('Not ranked yet'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('How points work'));
    await tester.pumpAndSettle();
    expect(find.text('How impact points work'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('network failures offer retry instead of claiming no activity', (tester) async {
    await tester.pumpWidget(Provider<F_User?>.value(value:F_User(uid:'me'),child:MaterialApp(home:LeaderboardScreen(service:FakeRanking(fail:true)))));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Not ranked yet'), findsNothing);
  });
}
