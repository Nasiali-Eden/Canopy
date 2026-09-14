import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Models/user.dart';
import '../../Services/Rank/leaderboard_service.dart';
import '../../Shared/theme/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  final LeaderboardService? service;
  const LeaderboardScreen({super.key, this.service});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final _service = widget.service ?? LeaderboardService();
  late Stream<List<RankEntry>> _board;
  Future<PersonalRank>? _personal;
  Stream<int>? _ownPoints;
  String? _uid;
  int _limit = 50;
  @override
  void initState() {
    super.initState();
    _board = _service.watchPeopleLeaderboard(limit: _limit);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = Provider.of<F_User?>(context)?.uid;
    if (_uid != uid) {
      _uid = uid;
      _ownPoints = uid == null ? null : _service.watchOwnPoints(uid);
      _personal = uid == null ? null : _service.getPersonalRank(uid);
    }
  }

  void _reload() => setState(() {
        _board = _service.watchPeopleLeaderboard(limit: _limit);
        _personal = _uid == null ? null : _service.getPersonalRank(_uid!);
      });
  void _rules() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('How Impact Points work',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    const Text(
                        'Only verified contributions count toward your rank. An approved verifier from the activity’s organisation reviews your contribution. You cannot verify your own work.'),
                    const SizedBox(height: 16),
                    const Text(
                        'Time • 10 points per hour, up to 24 hours per submission.\nEffort • 20 points for a verified contribution.\nMaterials • 20 points for a verified contribution.'),
                    const SizedBox(height: 16),
                    const Text(
                        'Longer descriptions, extra material labels and work categories do not earn bonuses. Pending estimates do not affect your position. Equal scores share a rank: 1, 1, 3.'),
                    const SizedBox(height: 16),
                    const Text(
                        'This is the global, all-time board for verified scoring version 1. Historical estimates are excluded until reviewed. Organisation accounts have a separate scoring model under development.'),
                    const SizedBox(height: 12),
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it')),
                  ]))));

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      appBar: AppBar(
          title: const Text('Community ranking'),
          backgroundColor: const Color(0xFFF5F7F2),
          actions: [
            IconButton(
                onPressed: _rules,
                tooltip: 'How points work',
                icon: const Icon(Icons.info_outline)),
            IconButton(
                onPressed: _reload,
                tooltip: 'Refresh ranking',
                icon: const Icon(Icons.refresh))
          ]),
      body: _uid == null
          ? const Center(child: Text('Sign in to see community rankings.'))
          : StreamBuilder<List<RankEntry>>(
              stream: _board,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return _error('We couldn’t load the ranking.');
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final entries = snapshot.data!;
                return ListView(padding: const EdgeInsets.all(20), children: [
                  Text('GROWING TOGETHER',
                      style: TextStyle(
                          letterSpacing: 2,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary)),
                  const SizedBox(height: 8),
                  const Text('Every contribution counts.',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                      'People · Global · All time\nRanked by verified Impact Points',
                      style: TextStyle(height: 1.6)),
                  const SizedBox(height: 20),
                  StreamBuilder<int>(
                      stream: _ownPoints,
                      builder: (context, own) {
                        if (own.hasError)
                          return _error('Your points are unavailable.');
                        return FutureBuilder<PersonalRank>(
                            future: _personal,
                            builder: (context, personal) {
                              if (personal.hasError)
                                return _error('Your position is unavailable.');
                              if (!personal.hasData)
                                return const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Center(
                                        child: CircularProgressIndicator()));
                              final p = personal.data!;
                              return _hero(
                                  p,
                                  own.data != null &&
                                      own.data != p.entry.points);
                            });
                      }),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/contributions/log'),
                      icon: const Icon(Icons.add),
                      label: const Text('Log a contribution')),
                  TextButton(
                      onPressed: _rules,
                      child: const Text('See scoring and verification rules')),
                  const SizedBox(height: 12),
                  const Text('Community leaders',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Equal points share the same position.'),
                  const SizedBox(height: 14),
                  if (entries.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                            'The verified board is just beginning. Your first verified contribution will earn your place.')),
                  for (var i = 0; i < entries.length; i++)
                    _row(entries[i], LeaderboardService.rankAt(entries, i)),
                  if (entries.length == _limit)
                    OutlinedButton(
                        onPressed: () {
                          _limit += 50;
                          _reload();
                        },
                        child: const Text('Show more contributors')),
                  const SizedBox(height: 24),
                  const Text('Organisation ranking',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text(
                      'Coming later, with a separate scoring policy for verified events and organisation impact.'),
                  const SizedBox(height: 20),
                ]);
              }));

  Widget _error(String message) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message),
        TextButton(onPressed: _reload, child: const Text('Try again'))
      ]));

  Widget _hero(PersonalRank p, bool stale) {
    final points = p.entry.points;
    final goal = points < 100
        ? 100
        : points < 500
            ? 500
            : points < 1000
                ? 1000
                : ((points ~/ 1000) + 1) * 1000;
    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: AppTheme.darkGreen, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOUR IMPACT',
              style: TextStyle(
                  color: Colors.white70, letterSpacing: 1.5, fontSize: 11)),
          const SizedBox(height: 14),
          Wrap(spacing: 32, runSpacing: 12, children: [
            Text(p.rank == null ? 'Not ranked yet' : '#${p.rank}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$points',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700)),
              const Text('verified points',
                  style: TextStyle(color: Colors.white70))
            ]),
          ]),
          const SizedBox(height: 18),
          Text(
              p.rank == null
                  ? 'Your first verified contribution starts your ranking.'
                  : p.pointsToNext == null
                      ? 'You share the highest score. Keep making a difference.'
                      : '${p.pointsToNext} points to move ahead of the next higher score.',
              style: const TextStyle(color: Colors.white, height: 1.5)),
          const SizedBox(height: 20),
          LinearProgressIndicator(
              value: points / goal,
              backgroundColor: Colors.white24,
              color: const Color(0xFFC9EB9A),
              minHeight: 6,
              semanticsLabel: 'Progress to $goal points'),
          const SizedBox(height: 8),
          Text('${goal - points} points to your $goal-point milestone',
              style: const TextStyle(color: Colors.white70)),
          Text('${p.pendingPoints} estimated points pending review', style: const TextStyle(color: Colors.white70)),
      if (stale)
            TextButton(
                onPressed: _reload,
                child: const Text('New points received — refresh your rank',
                    style: TextStyle(color: Colors.white))),
        ]));
  }

  Widget _row(RankEntry e, int rank) {
    final me = e.userId == _uid;
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: me ? const Color(0xFFE7EFDD) : Colors.white,
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          SizedBox(
              width: 48,
              child: Text('#$rank',
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE7EFDD),
              child: e.photoUrl == null
                  ? const Icon(Icons.person_outline)
                  : ClipOval(
                      child: Image.network(e.photoUrl!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person_outline)))),
          const SizedBox(width: 12),
          Expanded(
              child: Text(me ? '${e.name} (you)' : e.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Text('${e.points} pts',
              style: TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w800)),
        ]));
  }
}
