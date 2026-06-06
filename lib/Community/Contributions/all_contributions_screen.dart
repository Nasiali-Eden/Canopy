import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Shared/theme/app_theme.dart';
import 'contribution_card.dart';
import 'contribution_detail_sheet.dart';

const _kContributions = 'contributions';

const _kWorkTypes = [
  {'name': 'Cleanup', 'icon': Icons.cleaning_services},
  {'name': 'Tree Planting', 'icon': Icons.park},
  {'name': 'School Upgrading', 'icon': Icons.school},
  {'name': 'Waste Management', 'icon': Icons.recycling},
  {'name': 'Water & Sanitation', 'icon': Icons.water_drop},
  {'name': 'Infrastructure', 'icon': Icons.construction},
];

class AllContributionsScreen extends StatefulWidget {
  final String? userId;
  const AllContributionsScreen({super.key, this.userId});

  @override
  State<AllContributionsScreen> createState() =>
      _AllContributionsScreenState();
}

class _AllContributionsScreenState extends State<AllContributionsScreen> {
  String? _selectedType;
  String? _selectedStatus;

  int _totalContributions = 0;
  int _totalPoints = 0;
  int _verifiedCount = 0;
  bool _statsLoaded = false;

  final List<DocumentSnapshot> _docs = [];
  DocumentSnapshot? _lastDocument;
  bool _loadingMore = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPage();
    }
  }

  Future<void> _loadStats() async {
    if (widget.userId == null) return;
    try {
      // Firestore: contributions — one-time fetch for stats summary
      final snap = await FirebaseFirestore.instance
          .collection(_kContributions)
          .where('userId', isEqualTo: widget.userId)
          .get();
      int totalPts = 0;
      int verified = 0;
      for (final d in snap.docs) {
        final data = d.data();
        totalPts +=
            (data['pointsEarned'] as int? ?? data['points'] as int? ?? 0);
        if (data['status'] == 'verified') verified++;
      }
      if (mounted) {
        setState(() {
          _totalContributions = snap.docs.length;
          _totalPoints = totalPts;
          _verifiedCount = verified;
          _statsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  Future<void> _loadPage() async {
    if (_loadingMore || !_hasMore || widget.userId == null) return;
    setState(() => _loadingMore = true);
    try {
      // Firestore: contributions — paginated, ordered by createdAt desc
      var query = FirebaseFirestore.instance
          .collection(_kContributions)
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snap = await query.get();
      if (!mounted) return;
      setState(() {
        if (snap.docs.length < _pageSize) _hasMore = false;
        if (snap.docs.isNotEmpty) _lastDocument = snap.docs.last;
        _docs.addAll(snap.docs);
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _docs.clear();
      _lastDocument = null;
      _hasMore = true;
      _statsLoaded = false;
    });
    await Future.wait([_loadStats(), _loadPage()]);
  }

  List<DocumentSnapshot> get _filtered {
    return _docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final type = data['workType'] as String? ?? data['type'] as String?;
      final status = data['status'] as String?;
      if (_selectedType != null && type != _selectedType) return false;
      if (_selectedStatus != null && status != _selectedStatus) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = _selectedType != null || _selectedStatus != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3EE),
      appBar: AppBar(
        title: const Text('My Contributions',
            style: TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.darkGreen,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.primary,
        child: ListView(
          controller: _scrollController,
          children: [
            _StatsBanner(
              total: _totalContributions,
              points: _totalPoints,
              verified: _verifiedCount,
              loaded: _statsLoaded,
            ),
            const SizedBox(height: 16),
            // Type filter
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _selectedType == null,
                    onTap: () => setState(() => _selectedType = null),
                  ),
                  ..._kWorkTypes.map((t) => _FilterChip(
                        label: t['name'] as String,
                        icon: t['icon'] as IconData,
                        selected: _selectedType == t['name'],
                        onTap: () =>
                            setState(() => _selectedType = t['name'] as String),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Status filter
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _StatusPill(
                      label: 'All Status',
                      selected: _selectedStatus == null,
                      onTap: () => setState(() => _selectedStatus = null)),
                  _StatusPill(
                      label: 'Pending',
                      selected: _selectedStatus == 'pending',
                      color: Colors.amber.shade700,
                      onTap: () =>
                          setState(() => _selectedStatus = 'pending')),
                  _StatusPill(
                      label: 'Verified',
                      selected: _selectedStatus == 'verified',
                      color: Colors.green.shade600,
                      onTap: () =>
                          setState(() => _selectedStatus = 'verified')),
                  _StatusPill(
                      label: 'Rejected',
                      selected: _selectedStatus == 'rejected',
                      color: Colors.red.shade600,
                      onTap: () =>
                          setState(() => _selectedStatus = 'rejected')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_filtered.isEmpty && !_loadingMore)
              _EmptyState(hasFilter: hasFilter)
            else
              ...(_filtered.map((doc) {
                final contribution = {
                  ...(doc.data() as Map<String, dynamic>),
                  'id': doc.id,
                };
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) =>
                          ContributionDetailSheet(contribution: contribution),
                    ),
                    child: ContributionCard(contribution: contribution),
                  ),
                );
              })),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primary)),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Stats banner ──────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  final int total;
  final int points;
  final int verified;
  final bool loaded;

  const _StatsBanner(
      {required this.total,
      required this.points,
      required this.verified,
      required this.loaded});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.darkGreen, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppTheme.darkGreen.withOpacity(0.3),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          _BannerStat(value: loaded ? '$total' : '—', label: 'Total'),
          _vLine(),
          _BannerStat(value: loaded ? '$points' : '—', label: 'Points'),
          _vLine(),
          _BannerStat(value: loaded ? '$verified' : '—', label: 'Verified'),
        ],
      ),
    );
  }

  Widget _vLine() => Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withOpacity(0.2));
}

class _BannerStat extends StatelessWidget {
  final String value;
  final String label;
  const _BannerStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary
              : AppTheme.lightGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected ? Colors.white : AppTheme.darkGreen),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppTheme.darkGreen.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _StatusPill(
      {required this.label,
      required this.selected,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : AppTheme.darkGreen.withOpacity(0.2)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? c : AppTheme.darkGreen.withOpacity(0.6))),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(Icons.history_outlined,
              size: 56, color: AppTheme.lightGreen.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            hasFilter
                ? 'No contributions match this filter'
                : 'No contributions yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 6),
            Text('Try a different filter combination',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.5), fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
