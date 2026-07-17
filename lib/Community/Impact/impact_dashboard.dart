import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../Models/contribution.dart';
import '../../Models/user.dart';
import '../../Services/Impact/impact_service.dart';
import '../../Shared/theme/app_theme.dart';
import 'progress_visuals.dart';

class ImpactDashboardScreen extends StatefulWidget {
  final bool embedded;

  const ImpactDashboardScreen({super.key, this.embedded = false});

  @override
  State<ImpactDashboardScreen> createState() => _ImpactDashboardScreenState();
}

class _ImpactDashboardScreenState extends State<ImpactDashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);

    final content = Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.lightGreen.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'Community',
                        icon: Icons.people_outline,
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        label: 'My Impact',
                        icon: Icons.person_outline,
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.embedded)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        onPressed: user == null
                            ? null
                            : () async {
                                final csv = await ImpactService()
                                    .exportUserContributionsCsv(userId: user.uid);
                                await Clipboard.setData(ClipboardData(text: csv));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Exported CSV to clipboard'),
                                      backgroundColor: AppTheme.primary,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        icon: Icon(Icons.download_outlined, color: AppTheme.accent),
                        tooltip: 'Export CSV',
                      ),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('PDF export coming soon'),
                              backgroundColor: AppTheme.primary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: Icon(Icons.picture_as_pdf_outlined,
                            color: AppTheme.accent),
                        tooltip: 'Export PDF (coming soon)',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: _tab == 0
              ? _CommunityImpactTab(embedded: widget.embedded)
              : _MyImpactTab(embedded: widget.embedded, userId: user?.uid),
        ),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, color: AppTheme.primary, size: 24),
            const SizedBox(width: 10),
            Text(
              'Impact Dashboard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              if (user == null) {
                Navigator.pushReplacementNamed(context, '/welcome');
                return;
              }

              final csv = await ImpactService()
                  .exportUserContributionsCsv(userId: user.uid);
              await Clipboard.setData(ClipboardData(text: csv));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Exported CSV to clipboard'),
                    backgroundColor: AppTheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: Icon(Icons.download_outlined, color: AppTheme.accent),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: content,
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppTheme.darkGreen,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.darkGreen,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityImpactTab extends StatelessWidget {
  final bool embedded;

  const _CommunityImpactTab({required this.embedded});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ImpactService().watchCommunityTotalImpactPoints(),
      builder: (context, snapshot) {
        final total = snapshot.data ?? 0;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary,
                    AppTheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.analytics_outlined,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Community Total',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$total points',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.trending_up, color: Colors.white, size: 32),
                ],
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<List<Contribution>>(
              stream: ImpactService().watchCommunityContributions(),
              builder: (context, snapshot) {
                final list = snapshot.data ?? const [];
                return ProgressVisuals(contributions: list);
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.lightGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.tertiary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.picture_as_pdf_outlined,
                        color: AppTheme.tertiary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Report (PDF)',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkGreen,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Coming soon in next update',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.darkGreen.withOpacity(0.6),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      color: AppTheme.darkGreen.withOpacity(0.4), size: 18),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MyImpactTab extends StatelessWidget {
  final bool embedded;
  final String? userId;

  const _MyImpactTab({required this.embedded, required this.userId});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (userId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.login_outlined,
                    size: 40, color: AppTheme.primary),
              ),
              const SizedBox(height: 20),
              Text(
                'Sign in to View Impact',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGreen,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Track your contributions and see your environmental impact',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.darkGreen.withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/welcome'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text('Get Started'),
              ),
            ],
          ),
        ),
      );
    }

    final uid = userId!;

    return StreamBuilder<int>(
      stream: ImpactService().watchUserImpactPoints(userId: uid),
      builder: (context, pointsSnap) {
        final points = pointsSnap.data ?? 0;

        return StreamBuilder<List<Contribution>>(
          stream: ImpactService().watchUserContributions(userId: uid),
          builder: (context, contribSnap) {
            final list = contribSnap.data ?? const [];
            final summary = ImpactService()
                .summarize(impactPoints: points, contributions: list);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary,
                        AppTheme.accent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star_outline,
                              color: Colors.white.withOpacity(0.9), size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'My Impact Summary',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              label: 'Points',
                              value: '${summary.impactPoints}',
                              icon: Icons.bolt,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              label: 'Activities',
                              value: '${summary.contributionsCount}',
                              icon: Icons.check_circle_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              label: 'Hours',
                              value: summary.hours.toStringAsFixed(1),
                              icon: Icons.schedule,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ProgressVisuals(contributions: list),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.lightGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history, color: AppTheme.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Recent Contributions',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkGreen,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (list.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(Icons.eco_outlined,
                                    size: 48,
                                    color: AppTheme.lightGreen.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  'No contributions yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: AppTheme.darkGreen.withOpacity(0.6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Log your first contribution to see it here',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.darkGreen.withOpacity(0.5),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...list.take(10).map((c) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.eco_outlined,
                                      color: AppTheme.primary, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${c.type} contribution',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.darkGreen,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        c.createdAt == null
                                            ? 'Just now'
                                            : c.createdAt!
                                                .toLocal()
                                                .toString()
                                                .split('.')
                                                .first,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppTheme.darkGreen
                                                  .withOpacity(0.6),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.tertiary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.bolt,
                                          color: AppTheme.tertiary, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '+${c.estimatedImpactPoints}',
                                        style: TextStyle(
                                          color: AppTheme.tertiary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}